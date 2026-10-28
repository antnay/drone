//
//  EQAudioTap.swift
//  drone
//
//  MTAudioProcessingTap that runs the AVPlayer's audio through Apple's built-in
//  AUNBandEQ audio unit (Route A — no AVAudioEngine migration).
//
//  Threading contract:
//  - The tap process callback is a realtime C callback. It performs NO
//    allocations, locks, or Swift concurrency. It only calls CoreAudio C APIs
//    (MTAudioProcessingTapGetSourceAudio, AudioUnitRender).
//  - Parameter changes come from the main thread via AudioUnitSetParameter,
//    which is realtime-safe by design — we never read shared Swift state in the
//    process path. The AudioUnit instance is the single shared object, and it's
//    created in `prepare` and torn down in `unprepare`, both of which the
//    media framework serialises against `process`.
//

import AudioToolbox
import AVFoundation
import Foundation

// MARK: - Parameter snapshot

/// A plain-value snapshot of the EQ settings, suitable for reading from the
/// tap's prepare callback without touching @MainActor state. The controller
/// updates this (under `lock`) whenever settings change, so a freshly created
/// AudioUnit can be fully configured synchronously in `prepare`.
struct EQBandSnapshot {
    var frequency: Float
    var gain: Float
    var bandwidth: Float
    var filterType: Int
    var enabled: Bool
}

struct EQParamSnapshot {
    var enabled: Bool = false
    var preamp: Float = 0
    var bands: [EQBandSnapshot] = []

    /// Whether the EQ actually alters audio (on, and something non-flat).
    var isActive: Bool {
        guard enabled else { return false }
        if abs(preamp) > 0.001 { return true }
        return bands.contains { $0.enabled }
    }
}

// MARK: - Tap context

/// Heap object bridged into the tap's C callbacks via the tap storage pointer.
/// Holds the live AudioUnit so the controller can push parameters to it, plus
/// the processing format negotiated in `prepare`.
final class EQTapContext {
    /// The AUNBandEQ instance. Created in `prepare`, nil until then / after
    /// teardown. Read on the realtime thread (process) and set on the media
    /// framework's prepare/unprepare thread, which are mutually exclusive.
    var audioUnit: AudioUnit?

    /// Max frames the tap will ask us to render (set in prepare).
    var maxFrames: CMItemCount = 0

    /// Processing format the tap hands us (set in prepare).
    var processingFormat: AudioStreamBasicDescription = .init()

    /// Weak back-reference so the controller can push live parameter changes to
    /// the unit the moment it becomes available.
    weak var controller: EqualizerController?

    /// The tap itself, so the render-input callback can pull source audio via
    /// MTAudioProcessingTapGetSourceAudio directly into the AU's input buffers
    /// (the canonical in-place pattern). Unretained pointer; the tap outlives
    /// every process/render call. Set in prepare.
    var tapRef: Unmanaged<MTAudioProcessingTap>?
    /// Frames the current AudioUnitRender pass should pull (set in process).
    var currentFrameCount: CMItemCount = 0

    /// Current settings snapshot, read by `prepare` to configure a new unit.
    /// Guarded by `lock` since it's written on main and read on the media
    /// framework's prepare thread.
    private var snapshot = EQParamSnapshot()
    private let lock = NSLock()

    func updateSnapshot(_ new: EQParamSnapshot) {
        lock.lock(); snapshot = new; lock.unlock()
        bypass = !new.isActive
    }

    func currentSnapshot() -> EQParamSnapshot {
        lock.lock(); defer { lock.unlock() }
        return snapshot
    }

    /// Monotonic sample time fed to AudioUnitRender so the AU sees a continuous
    /// timeline (some AUs misbehave with a stuck timestamp). Advanced in process.
    var sampleTime: Int64 = 0

    /// When false, `process` skips AudioUnitRender entirely and passes source
    /// audio through untouched. Plain Bool read on the realtime thread;
    /// single-writer from main, worst case a one-cycle-late toggle (harmless).
    var bypass: Bool = true

    // Logging rate-limit state (realtime-safe plain Ints, touched only in
    // `process`). First few cycles log in full; afterwards only on change.
    var processCallCount: Int = 0
    var lastLoggedBypass: Bool? = nil
    var lastLoggedRenderStatus: OSStatus = 0

    init(controller: EqualizerController?) {
        self.controller = controller
    }
}

// MARK: - Tap factory

enum EQAudioTap {

    /// Writes every band parameter + global gain from `snapshot` into the unit.
    /// Called from `prepare` (post-init) and reused by live updates. Safe to
    /// call on any thread — AudioUnitSetParameter is realtime-safe.
    static func configureParameters(_ au: AudioUnit, from snapshot: EQParamSnapshot) {
        let masterOn = snapshot.enabled

        let ggValue: Float = masterOn ? snapshot.preamp : 0
        let ggStatus = AudioUnitSetParameter(
            au, kAUNBandEQParam_GlobalGain,
            kAudioUnitScope_Global, 0, ggValue, 0
        )
        EQLog.controller.log("configureParameters: master=\(masterOn, privacy: .public) GlobalGain=\(ggValue, privacy: .public) -> \(EQLog.osStatusString(ggStatus), privacy: .public) bands=\(snapshot.bands.count, privacy: .public)")
        EQLog.line("controller", "configure: master=\(masterOn) GlobalGain=\(ggValue) -> \(EQLog.osStatusString(ggStatus)) bands=\(snapshot.bands.count)")

        var worstStatus: OSStatus = ggStatus
        // Configure all maxBands slots: real bands from the snapshot, the rest
        // bypassed (the unit always has maxBands bands allocated).
        for index in 0..<EQSettings.maxBands {
            let i = AudioUnitParameterID(index)
            if index < snapshot.bands.count {
                let band = snapshot.bands[index]
                let bandOn = masterOn && band.enabled
                // Bypass is inverted: 1 = bypassed.
                let s1 = AudioUnitSetParameter(au, kAUNBandEQParam_BypassBand + i, kAudioUnitScope_Global, 0, bandOn ? 0 : 1, 0)
                let s2 = AudioUnitSetParameter(au, kAUNBandEQParam_FilterType + i, kAudioUnitScope_Global, 0, Float(band.filterType), 0)
                let s3 = AudioUnitSetParameter(au, kAUNBandEQParam_Frequency + i, kAudioUnitScope_Global, 0, band.frequency, 0)
                let s4 = AudioUnitSetParameter(au, kAUNBandEQParam_Gain + i, kAudioUnitScope_Global, 0, band.gain, 0)
                let s5 = AudioUnitSetParameter(au, kAUNBandEQParam_Bandwidth + i, kAudioUnitScope_Global, 0, band.bandwidth, 0)
                for s in [s1, s2, s3, s4, s5] where s != noErr { worstStatus = s }
                EQLog.line("controller", "  band[\(index)] on=\(bandOn) f=\(band.frequency) g=\(band.gain) bw=\(band.bandwidth) type=\(band.filterType) status(bypass/type/freq/gain/bw)=\(s1)/\(s2)/\(s3)/\(s4)/\(s5)")
            } else {
                // Unused slot: bypass so it has no effect.
                _ = AudioUnitSetParameter(au, kAUNBandEQParam_BypassBand + i, kAudioUnitScope_Global, 0, 1, 0)
            }
        }
        if worstStatus != noErr {
            EQLog.controller.error("configureParameters: at least one SetParameter FAILED, worst=\(EQLog.osStatusString(worstStatus), privacy: .public)")
            EQLog.line("controller", "WARNING worst SetParameter status=\(EQLog.osStatusString(worstStatus))")
        }
    }

    /// Builds an AVAudioMix that installs an EQ processing tap on the given
    /// track, wired to `context`. Returns nil if the tap can't be created.
    static func makeAudioMix(
        for track: AVAssetTrack,
        context: EQTapContext
    ) -> AVAudioMix? {
        var callbacks = MTAudioProcessingTapCallbacks(
            version: kMTAudioProcessingTapCallbacksVersion_0,
            clientInfo: UnsafeMutableRawPointer(
                Unmanaged.passRetained(context).toOpaque()
            ),
            init: tapInit,
            finalize: tapFinalize,
            prepare: tapPrepare,
            unprepare: tapUnprepare,
            process: tapProcess
        )

        var tap: MTAudioProcessingTap?
        let status = MTAudioProcessingTapCreate(
            kCFAllocatorDefault,
            &callbacks,
            kMTAudioProcessingTapCreationFlag_PostEffects,
            &tap
        )
        guard status == noErr, let createdTap = tap else {
            EQLog.tap.error("MTAudioProcessingTapCreate FAILED: \(EQLog.osStatusString(status), privacy: .public)")
            EQLog.line("tap", "MTAudioProcessingTapCreate FAILED: \(EQLog.osStatusString(status))")
            // Balance the passRetained above if creation failed.
            Unmanaged<EQTapContext>.fromOpaque(
                callbacks.clientInfo!
            ).release()
            return nil
        }
        EQLog.tap.log("MTAudioProcessingTapCreate OK")
        EQLog.line("tap", "MTAudioProcessingTapCreate OK")

        let params = AVMutableAudioMixInputParameters(track: track)
        params.audioTapProcessor = createdTap

        let mix = AVMutableAudioMix()
        mix.inputParameters = [params]
        return mix
    }
}

// MARK: - C callbacks (realtime-safe)

private func tapInit(
    _ tap: MTAudioProcessingTap,
    _ clientInfo: UnsafeMutableRawPointer?,
    _ tapStorageOut: UnsafeMutablePointer<UnsafeMutableRawPointer?>
) {
    // Hand the already-retained context through to tap storage.
    tapStorageOut.pointee = clientInfo
    EQLog.tap.log("tapInit")
    EQLog.line("tap", "tapInit")
}

private func tapFinalize(_ tap: MTAudioProcessingTap) {
    EQLog.tap.log("tapFinalize")
    EQLog.line("tap", "tapFinalize")
    let storage = MTAudioProcessingTapGetStorage(tap)
    // Release the retain taken in makeAudioMix.
    Unmanaged<EQTapContext>.fromOpaque(storage).release()
}

private func tapPrepare(
    _ tap: MTAudioProcessingTap,
    _ maxFrames: CMItemCount,
    _ processingFormat: UnsafePointer<AudioStreamBasicDescription>
) {
    let context = Unmanaged<EQTapContext>
        .fromOpaque(MTAudioProcessingTapGetStorage(tap))
        .takeUnretainedValue()

    context.maxFrames = maxFrames
    context.processingFormat = processingFormat.pointee

    let fmt = processingFormat.pointee
    let nonInterleaved = (fmt.mFormatFlags & kAudioFormatFlagIsNonInterleaved) != 0
    let isFloat = (fmt.mFormatFlags & kAudioFormatFlagIsFloat) != 0
    EQLog.tap.log("""
        tapPrepare: sampleRate=\(fmt.mSampleRate, privacy: .public) \
        channels=\(fmt.mChannelsPerFrame, privacy: .public) \
        bits=\(fmt.mBitsPerChannel, privacy: .public) \
        float=\(isFloat, privacy: .public) \
        nonInterleaved=\(nonInterleaved, privacy: .public) \
        maxFrames=\(maxFrames, privacy: .public)
        """)
    EQLog.line("tap", "prepare: sr=\(fmt.mSampleRate) ch=\(fmt.mChannelsPerFrame) bits=\(fmt.mBitsPerChannel) float=\(isFloat) nonInterleaved=\(nonInterleaved) maxFrames=\(maxFrames)")

    // Instantiate Apple's AUNBandEQ effect unit.
    var desc = AudioComponentDescription(
        componentType: kAudioUnitType_Effect,
        componentSubType: kAudioUnitSubType_NBandEQ,
        componentManufacturer: kAudioUnitManufacturer_Apple,
        componentFlags: 0,
        componentFlagsMask: 0
    )
    guard let component = AudioComponentFindNext(nil, &desc) else {
        EQLog.tap.error("tapPrepare: AudioComponentFindNext(NBandEQ) returned nil")
        EQLog.line("tap", "AudioComponentFindNext(NBandEQ) returned nil")
        return
    }
    EQLog.tap.log("tapPrepare: found AUNBandEQ component")

    var unit: AudioUnit?
    let newStatus = AudioComponentInstanceNew(component, &unit)
    guard newStatus == noErr, let audioUnit = unit else {
        EQLog.tap.error("tapPrepare: AudioComponentInstanceNew FAILED: \(EQLog.osStatusString(newStatus), privacy: .public)")
        EQLog.line("tap", "AudioComponentInstanceNew FAILED: \(EQLog.osStatusString(newStatus))")
        return
    }

    let snapshot = context.currentSnapshot()
    EQLog.tap.log("tapPrepare: snapshot enabled=\(snapshot.enabled, privacy: .public) preamp=\(snapshot.preamp, privacy: .public) bands=\(snapshot.bands.count, privacy: .public) isActive=\(snapshot.isActive, privacy: .public)")
    EQLog.line("tap", "snapshot enabled=\(snapshot.enabled) preamp=\(snapshot.preamp) bands=\(snapshot.bands.count) isActive=\(snapshot.isActive)")

    // NumberOfBands must be set BEFORE initialization — it changes the unit's
    // parameter layout. We always allocate the maximum, and treat unused slots
    // as bypassed.
    var bandCount = UInt32(EQSettings.maxBands)
    let nbStatus = AudioUnitSetProperty(
        audioUnit, kAUNBandEQProperty_NumberOfBands,
        kAudioUnitScope_Global, 0, &bandCount,
        UInt32(MemoryLayout<UInt32>.size)
    )
    EQLog.line("tap", "set NumberOfBands=\(bandCount) -> \(EQLog.osStatusString(nbStatus))")

    // Match the EQ's stream format to the tap's processing format on both the
    // input and output scopes.
    var format = processingFormat.pointee
    let inFmtStatus = AudioUnitSetProperty(
        audioUnit, kAudioUnitProperty_StreamFormat,
        kAudioUnitScope_Input, 0, &format,
        UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
    )
    let outFmtStatus = AudioUnitSetProperty(
        audioUnit, kAudioUnitProperty_StreamFormat,
        kAudioUnitScope_Output, 0, &format,
        UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
    )
    EQLog.line("tap", "set StreamFormat in=\(EQLog.osStatusString(inFmtStatus)) out=\(EQLog.osStatusString(outFmtStatus))")

    // Tell the unit the maximum block size it must handle.
    var maxFramesPerSlice = UInt32(maxFrames)
    let mfStatus = AudioUnitSetProperty(
        audioUnit, kAudioUnitProperty_MaximumFramesPerSlice,
        kAudioUnitScope_Global, 0, &maxFramesPerSlice,
        UInt32(MemoryLayout<UInt32>.size)
    )
    EQLog.line("tap", "set MaxFramesPerSlice=\(maxFramesPerSlice) -> \(EQLog.osStatusString(mfStatus))")

    // Install a render-input callback so AudioUnitRender pulls the source audio
    // (copied into a scratch buffer in `process`) through the EQ.
    var renderCallback = AURenderCallbackStruct(
        inputProc: eqRenderCallback,
        inputProcRefCon: MTAudioProcessingTapGetStorage(tap)
    )
    let cbStatus = AudioUnitSetProperty(
        audioUnit, kAudioUnitProperty_SetRenderCallback,
        kAudioUnitScope_Input, 0, &renderCallback,
        UInt32(MemoryLayout<AURenderCallbackStruct>.size)
    )
    EQLog.line("tap", "set RenderCallback -> \(EQLog.osStatusString(cbStatus))")

    let initStatus = AudioUnitInitialize(audioUnit)
    guard initStatus == noErr else {
        EQLog.tap.error("tapPrepare: AudioUnitInitialize FAILED: \(EQLog.osStatusString(initStatus), privacy: .public)")
        EQLog.line("tap", "AudioUnitInitialize FAILED: \(EQLog.osStatusString(initStatus))")
        AudioComponentInstanceDispose(audioUnit)
        return
    }
    EQLog.tap.log("tapPrepare: AudioUnitInitialize OK")
    EQLog.line("tap", "AudioUnitInitialize OK")

    // Configure all band parameters + global gain synchronously from the
    // snapshot, so the unit is fully set up the instant it starts processing.
    EQAudioTap.configureParameters(audioUnit, from: snapshot)

    // Keep an unretained reference to the tap so the render-input callback can
    // pull source audio directly into the AU's input buffers.
    context.tapRef = Unmanaged.passUnretained(tap)

    context.audioUnit = audioUnit
    context.bypass = !snapshot.isActive
    // Reset per-prepare logging + render-timeline state for the new item.
    context.processCallCount = 0
    context.lastLoggedBypass = nil
    context.lastLoggedRenderStatus = 0
    context.sampleTime = 0
    EQLog.tap.log("tapPrepare: DONE, unit ready, bypass=\(context.bypass, privacy: .public)")
    EQLog.line("tap", "prepare DONE, unit ready, bypass=\(context.bypass)")
}

private func tapUnprepare(_ tap: MTAudioProcessingTap) {
    EQLog.tap.log("tapUnprepare")
    EQLog.line("tap", "tapUnprepare")
    let context = Unmanaged<EQTapContext>
        .fromOpaque(MTAudioProcessingTapGetStorage(tap))
        .takeUnretainedValue()

    if let audioUnit = context.audioUnit {
        AudioUnitUninitialize(audioUnit)
        AudioComponentInstanceDispose(audioUnit)
        context.audioUnit = nil
    }
    context.tapRef = nil
}

private func tapProcess(
    _ tap: MTAudioProcessingTap,
    _ numberFrames: CMItemCount,
    _ flags: MTAudioProcessingTapFlags,
    _ bufferListInOut: UnsafeMutablePointer<AudioBufferList>,
    _ numberFramesOut: UnsafeMutablePointer<CMItemCount>,
    _ flagsOut: UnsafeMutablePointer<MTAudioProcessingTapFlags>
) {
    let context = Unmanaged<EQTapContext>
        .fromOpaque(MTAudioProcessingTapGetStorage(tap))
        .takeUnretainedValue()

    context.processCallCount += 1
    let verbose = context.processCallCount <= 5
    let bypassChanged = context.lastLoggedBypass != context.bypass

    // EQ off / bypassed / unit not ready: just pass source straight through
    // into bufferListInOut (the untapped audio).
    guard let audioUnit = context.audioUnit, !context.bypass else {
        var sourceFlags = MTAudioProcessingTapFlags()
        var framesProvided: CMItemCount = 0
        _ = MTAudioProcessingTapGetSourceAudio(
            tap, numberFrames, bufferListInOut, &sourceFlags, nil, &framesProvided
        )
        numberFramesOut.pointee = framesProvided
        flagsOut.pointee = sourceFlags
        if verbose || bypassChanged {
            context.lastLoggedBypass = context.bypass
            EQLog.line("process", "#\(context.processCallCount) PASSTHROUGH framesReq=\(numberFrames) provided=\(framesProvided) bypass=\(context.bypass) unit=\(context.audioUnit != nil)")
        }
        return
    }

    // Active path: drive the AU. Its render-input callback pulls the source
    // audio via GetSourceAudio directly into the AU's input buffers (canonical
    // in-place MTAudioProcessingTap pattern), and AudioUnitRender writes the
    // EQ'd result into bufferListInOut.
    context.currentFrameCount = numberFrames

    var timeStamp = AudioTimeStamp()
    timeStamp.mFlags = .sampleTimeValid
    timeStamp.mSampleTime = Float64(context.sampleTime)
    var renderFlags = AudioUnitRenderActionFlags()

    let renderStatus = AudioUnitRender(
        audioUnit, &renderFlags, &timeStamp, 0,
        UInt32(numberFrames), bufferListInOut
    )

    if renderStatus == noErr {
        numberFramesOut.pointee = numberFrames
        context.sampleTime += Int64(numberFrames)
    } else {
        // Fallback: on render failure, emit the untouched source so audio
        // doesn't drop out.
        var sourceFlags = MTAudioProcessingTapFlags()
        var framesProvided: CMItemCount = 0
        _ = MTAudioProcessingTapGetSourceAudio(
            tap, numberFrames, bufferListInOut, &sourceFlags, nil, &framesProvided
        )
        numberFramesOut.pointee = framesProvided
        flagsOut.pointee = sourceFlags
    }

    if verbose || renderStatus != context.lastLoggedRenderStatus || bypassChanged {
        context.lastLoggedRenderStatus = renderStatus
        context.lastLoggedBypass = context.bypass
        var outSample: Float = 0
        let outBuffers = UnsafeMutableAudioBufferListPointer(bufferListInOut)
        if let p = outBuffers.first?.mData {
            outSample = p.assumingMemoryBound(to: Float.self)[0]
        }
        EQLog.process.log("process #\(context.processCallCount, privacy: .public): render=\(EQLog.osStatusString(renderStatus), privacy: .public) frames=\(numberFrames, privacy: .public) outSample=\(outSample, privacy: .public)")
        EQLog.line("process", "#\(context.processCallCount) render=\(EQLog.osStatusString(renderStatus)) frames=\(numberFrames) outSample=\(outSample)")
    }
}

/// Render-input callback for the EQ unit: pulls the tap's source audio directly
/// into the AU's input buffers. Runs synchronously inside AudioUnitRender on
/// the realtime thread. Realtime-safe: no allocations or locks.
private func eqRenderCallback(
    _ inRefCon: UnsafeMutableRawPointer,
    _ ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
    _ inTimeStamp: UnsafePointer<AudioTimeStamp>,
    _ inBusNumber: UInt32,
    _ inNumberFrames: UInt32,
    _ ioData: UnsafeMutablePointer<AudioBufferList>?
) -> OSStatus {
    let context = Unmanaged<EQTapContext>
        .fromOpaque(inRefCon)
        .takeUnretainedValue()

    guard let ioData, let tapRef = context.tapRef else { return noErr }
    let tap = tapRef.takeUnretainedValue()

    var sourceFlags = MTAudioProcessingTapFlags()
    var framesProvided: CMItemCount = 0
    let status = MTAudioProcessingTapGetSourceAudio(
        tap,
        CMItemCount(inNumberFrames),
        ioData,
        &sourceFlags,
        nil,
        &framesProvided
    )
    return status
}
