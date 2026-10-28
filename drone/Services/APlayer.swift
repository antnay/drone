//
//  APlayer.swift
//  drone
//
//  Created by Anthony on 5/19/26.
//

import AVFoundation
import Combine
import CoreAudio
import MediaPlayer
import SwiftUI

@MainActor
class APlayer: ObservableObject {
    @Published var current: Song?
    @Published var nowPlayingImage: NSImage?
    @Published var isPlaying: Bool = false
    @Published var queue: [Song] = []
    @Published var curIndex: Int = 0
    @Published var currentTime: Double = 0
    @Published var isShuffling: Bool = false
    /// Controls visibility of the right-side queue sidebar. Lives here (rather
    /// than in a view) because the toggle (PlayerView) and the panel itself
    /// (ContentView) are in separate parts of the hierarchy.
    @Published var showQueueSidebar: Bool = false
    @Published var volume: Float = 1.0 {
        didSet {
            player.volume = volume
            UserDefaults.standard.set(volume, forKey: "playerVolume")
        }
    }

    var currentDuration: Double { Double(current?.duration ?? 0) }

    /// Parametric equalizer. Owns the EQ settings and the AUNBandEQ unit that
    /// runs inside the audio tap installed on each AVPlayerItem.
    let equalizer = EqualizerController()

    var shuffler = LibraryShuffler()

    private let player = AVPlayer()
    private var timeObserver: Any?
    private var endOfItemObserver: NSObjectProtocol?
    private var failedItemObserver: NSObjectProtocol?

    // CoreAudio: listens for the system default output device changing. macOS
    // has no AVAudioSession route-change notification, so this is how we detect
    // an AirPod being removed (macOS auto-switches output to built-in speakers).
    private let defaultOutputDeviceAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    private var outputDeviceListener: AudioObjectPropertyListenerBlock?

    var server: Server?

    init(server: Server? = nil) {
        self.current = nil
        self.isPlaying = false
        self.queue = []
        self.curIndex = 0
        self.server = server

        let saved = UserDefaults.standard.float(forKey: "playerVolume")
        let initialVolume: Float = saved > 0 ? saved : 1.0
        self.volume = initialVolume
        player.volume = initialVolume

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self else { return }
            let seconds = time.seconds
            if !seconds.isNaN && !seconds.isInfinite {
                self.currentTime = seconds
            }
        }

        setupCC()
        setupOutputDeviceListener()
        endOfItemObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.forward()
            }
        }
        failedItemObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let error = note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey]
                as? Error
            Task { @MainActor in
                self?.handlePlaybackFailure(error)
            }
        }
    }

    nonisolated deinit {
        // AVPlayer.removeTimeObserver and NotificationCenter.removeObserver are
        // both safe to call from any thread.
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
        }
        if let observer = endOfItemObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = failedItemObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let listener = outputDeviceListener {
            // Must remove with the exact same address + block we registered.
            var address = defaultOutputDeviceAddress
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                DispatchQueue.main,
                listener
            )
        }
    }

    private func handlePlaybackFailure(_ error: Error?) {
        Server.logger.error(
            "Playback failed: \(error?.localizedDescription ?? "unknown error")"
        )
        player.pause()
        isPlaying = false
        MPNowPlayingInfoCenter.default().playbackState = .paused
        updateNowPlaying()
    }

    func shuffleAlbum(_ songs: [Song]) {
        queue = songs.shuffled()
        curIndex = 0
        play()
    }

    func shuffleLibrary() async {
        guard let server, !isShuffling else { return }
        isShuffling = true
        defer { isShuffling = false }
        do {
            let songs = try await shuffler.shuffle(server: server)
            queue = songs
            curIndex = 0
            play()
        } catch {
            Server.logger.error("Library shuffle failed: \(error.localizedDescription)")
        }
    }

    func playAlbum(songs: [Song], startingAt: Int = 0) {
        Server.logger.debug("play album")
        queue = songs
        curIndex = startingAt
        play()
    }

    func play() {
        Server.logger.debug("play")
        guard !queue.isEmpty else { return }

        player.pause()
        currentTime = 0

        current = queue[curIndex]
        guard let current else { return }

        guard let url = server?.streamURL(for: current.songID) else { return }
        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        player.replaceCurrentItem(with: playerItem)

        // Attach the EQ tap BEFORE starting playback. Setting audioMix on an
        // item that's already playing often doesn't take effect (the pipeline
        // is already built), so we defer player.play() until the mix is set.
        installEQTap(on: playerItem, asset: asset)

        isPlaying = true
        MPNowPlayingInfoCenter.default().playbackState = .playing

        Task {
            if !current.coverArt.isEmpty {
                if let data = try? await server?.getCoverArt(
                    id: current.coverArt
                ) {
                    nowPlayingImage = try? await ImageCacheManager.shared.image(
                        for: current.coverArt,
                        data: data
                    )
                }
            } else {
                nowPlayingImage = nil
            }
            updateNowPlaying()
        }
    }

    /// Loads the asset's audio track, installs the EQ processing tap on the
    /// given item, and THEN starts playback. Attaching audioMix before
    /// play() is what makes the tap actually engage. Heavily logged so we can
    /// see exactly where the pipeline breaks.
    private func installEQTap(on item: AVPlayerItem, asset: AVURLAsset) {
        let context = equalizer.tapContext
        EQLog.install.log("installEQTap: begin for item \(ObjectIdentifier(item).debugDescription, privacy: .public)")
        EQLog.line("install", "begin for item \(ObjectIdentifier(item))")

        let start = Date()
        Task {
            let track: AVAssetTrack?
            do {
                track = try await asset.loadTracks(withMediaType: .audio).first
            } catch {
                EQLog.install.error("installEQTap: loadTracks FAILED: \(error.localizedDescription, privacy: .public)")
                EQLog.line("install", "loadTracks FAILED: \(error.localizedDescription)")
                await MainActor.run { self.player.play() }  // play anyway, untapped
                return
            }

            let elapsedMs = Date().timeIntervalSince(start) * 1000
            guard let track else {
                EQLog.install.error("installEQTap: no audio track found (after \(elapsedMs, format: .fixed(precision: 1))ms)")
                EQLog.line("install", "no audio track found after \(String(format: "%.1f", elapsedMs))ms")
                await MainActor.run { self.player.play() }
                return
            }
            EQLog.install.log("installEQTap: audio track loaded in \(elapsedMs, format: .fixed(precision: 1), privacy: .public)ms")
            EQLog.line("install", "audio track loaded in \(String(format: "%.1f", elapsedMs))ms")

            let mix = EQAudioTap.makeAudioMix(for: track, context: context)
            EQLog.install.log("installEQTap: makeAudioMix returned \(mix == nil ? "nil" : "non-nil", privacy: .public)")
            EQLog.line("install", "makeAudioMix -> \(mix == nil ? "nil" : "non-nil")")

            await MainActor.run {
                let stillCurrent = self.player.currentItem === item
                if stillCurrent {
                    item.audioMix = mix
                    let attached = item.audioMix != nil
                    EQLog.install.log("installEQTap: audioMix set; item.audioMix != nil = \(attached, privacy: .public); starting play()")
                    EQLog.line("install", "audioMix set, non-nil=\(attached); starting play()")
                    self.player.play()
                } else {
                    EQLog.install.log("installEQTap: item no longer current; skipping mix + play")
                    EQLog.line("install", "item no longer current; skipping")
                }
            }
        }
    }

    func pause() {
        Server.logger.debug("pause")
        guard current != nil else { return }
        self.player.pause()
        isPlaying = false
        MPNowPlayingInfoCenter.default().playbackState = .paused
        updateNowPlaying()
    }

    func resume() {
        Server.logger.debug("resume")
        guard current != nil else { return }
        self.player.play()
        isPlaying = true
        MPNowPlayingInfoCenter.default().playbackState = .playing
        updateNowPlaying()
    }

    func forward() {
        Server.logger.debug("forward")
        guard curIndex + 1 < queue.count else {
            // Reached the end of the queue: stop playback state so the
            // transport controls and now-playing info don't stay "playing".
            player.pause()
            isPlaying = false
            MPNowPlayingInfoCenter.default().playbackState = .paused
            updateNowPlaying()
            return
        }
        curIndex += 1
        play()
    }

    func back() {
        Server.logger.debug("back")
        guard curIndex - 1 >= 0 else { return }
        curIndex -= 1
        play()
    }

    func jumpTo(index: Int) {
        guard index >= 0, index < queue.count else { return }
        curIndex = index
        play()
    }

    func addNext(song: Song) {
        if queue.isEmpty {
            queue = [song]; curIndex = 0; play()
        } else {
            queue.insert(song, at: curIndex + 1)
        }
    }

    func addToQueue(song: Song) {
        if queue.isEmpty {
            queue = [song]; curIndex = 0; play()
        } else {
            queue.append(song)
        }
    }

    /// Songs queued to play after the current track, in play order
    /// (`upcoming.first` is the very next song).
    var upcoming: ArraySlice<Song> {
        let start = curIndex + 1
        guard start < queue.count else { return [] }
        return queue[start...]
    }

    /// Removes every song after the current track, leaving the current one
    /// playing. If nothing is playing, empties the queue entirely.
    func clearQueue() {
        if current != nil, curIndex < queue.count {
            queue.removeSubrange((curIndex + 1)...)
        } else {
            queue = []
            curIndex = 0
        }
    }

    func removeFromQueue(at index: Int) {
        guard index >= 0, index < queue.count else { return }
        queue.remove(at: index)
        if index < curIndex {
            curIndex -= 1
        } else if index == curIndex {
            if curIndex >= queue.count { curIndex = max(0, queue.count - 1) }
            if !queue.isEmpty { play() } else { current = nil; isPlaying = false }
        }
    }

    /// Registers a CoreAudio listener for changes to the system default output
    /// device. When an AirPod (or any output device) is removed, macOS switches
    /// the default output — e.g. to the built-in speakers — which fires this
    /// listener. We pause playback in response, mirroring the "unplug
    /// headphones = pause" behaviour of Apple Music. There's no AVAudioSession
    /// on macOS, so CoreAudio is the correct route-change signal here.
    private func setupOutputDeviceListener() {
        var address = defaultOutputDeviceAddress
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            // The callback is delivered on the DispatchQueue we pass below
            // (main), but APlayer is @MainActor-isolated, so hop explicitly to
            // satisfy isolation regardless of delivery thread.
            Task { @MainActor [weak self] in
                guard let self, self.isPlaying else { return }
                self.pause()
            }
        }
        let status = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            DispatchQueue.main,
            listener
        )
        if status == noErr {
            outputDeviceListener = listener
        } else {
            Server.logger.error(
                "Failed to register default-output-device listener: \(status)"
            )
        }
    }

    private func setupCC() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            if self.isPlaying {
                self.pause()
            } else {
                self.resume()
            }
            return .success
        }

        // AirPods stem presses and the system often send the *discrete* play /
        // pause commands rather than the toggle, so handle them explicitly or
        // they get dropped and the AirPod gesture appears to do nothing.
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self, self.current != nil, !self.isPlaying else {
                return .commandFailed
            }
            self.resume()
            return .success
        }

        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self, self.current != nil, self.isPlaying else {
                return .commandFailed
            }
            self.pause()
            return .success
        }

        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.forward()
            return .success
        }

        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.back()
            return .success
        }

        commandCenter.changePlaybackPositionCommand.addTarget {
            [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent
            else { return .commandFailed }
            self?.seek(to: event.positionTime)
            return .success
        }
    }

    func updateNowPlaying() {
        guard let song = current else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: song.title,
            MPMediaItemPropertyArtist: song.artist,
            MPMediaItemPropertyAlbumTitle: song.album,
            MPMediaItemPropertyPlaybackDuration: Double(song.duration),
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]

        if let image = nowPlayingImage {
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in
                image
            }
            info[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    func seek(to time: Double) {
        player.seek(to: CMTime(seconds: time, preferredTimescale: 600))
        currentTime = time
        updateNowPlaying()
    }
}
