//
//  EqualizerController.swift
//  drone
//
//  Owns the EQ settings and bridges them to the AUNBandEQ unit living inside
//  the audio tap. All parameter pushes go through AudioUnitSetParameter, which
//  is realtime-safe, so the audio thread never reads Swift state.
//

import AudioToolbox
import Combine
import Foundation

@MainActor
final class EqualizerController: ObservableObject {
    /// The live EQ settings. Any mutation re-pushes parameters to the unit and
    /// persists the state.
    @Published var settings: EQSettings {
        didSet { onSettingsChanged() }
    }

    /// User-saved presets (built-ins are provided separately and not stored).
    @Published private(set) var userPresets: [EQPreset] = []

    /// The tap context whose AudioUnit we drive. Shared with the tap callbacks.
    let tapContext: EQTapContext

    private let defaults = UserDefaults.standard
    private let settingsKey = "eq.currentSettings"
    private let presetsKey = "eq.userPresets"

    init() {
        // Build context first (needs `self` as controller), then restore state.
        let context = EQTapContext(controller: nil)
        self.tapContext = context
        self.settings = Self.loadSettings(defaults: UserDefaults.standard)
        context.controller = self
        self.userPresets = loadUserPresets()
        // Seed the tap context so the first track's `prepare` sees the restored
        // settings (didSet doesn't fire during init).
        context.updateSnapshot(makeSnapshot())
        EQLog.controller.log("init: seeded snapshot enabled=\(self.settings.enabled, privacy: .public) preamp=\(self.settings.preamp, privacy: .public) bands=\(self.settings.bands.count, privacy: .public) bypass=\(context.bypass, privacy: .public)")
        EQLog.line("controller", "init seeded: enabled=\(settings.enabled) preamp=\(settings.preamp) bands=\(settings.bands.count) bypass=\(context.bypass)")
    }

    // MARK: - Presets

    func apply(preset: EQPreset) {
        settings = preset.settings
    }

    /// Resets to the neutral default: preamp 0 and the standard ISO band layout
    /// at 0 dB. Keeps the master on/off state the user currently has.
    func resetToFlat() {
        settings = EQSettings(
            enabled: settings.enabled,
            preamp: 0,
            bands: EQPreset.flatBands
        )
    }

    /// Saves the current settings as a new user preset.
    func saveAsPreset(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let idx = userPresets.firstIndex(where: { $0.name == trimmed }) {
            userPresets[idx].settings = settings
        } else {
            userPresets.append(EQPreset(name: trimmed, settings: settings))
        }
        persistUserPresets()
    }

    func deletePreset(_ preset: EQPreset) {
        userPresets.removeAll { $0.id == preset.id }
        persistUserPresets()
    }

    // MARK: - Band editing

    func addBand(frequency: Double, gain: Double = 0) -> EQBand? {
        guard settings.bands.count < EQSettings.maxBands else { return nil }
        let band = EQBand(frequency: frequency, gain: gain).clamped()
        settings.bands.append(band)
        settings.bands.sort { $0.frequency < $1.frequency }
        EQLog.controller.log("addBand f=\(band.frequency, privacy: .public) g=\(band.gain, privacy: .public) -> count=\(self.settings.bands.count, privacy: .public)")
        return band
    }

    func removeBand(id: UUID) {
        settings.bands.removeAll { $0.id == id }
        EQLog.controller.log("removeBand -> count=\(self.settings.bands.count, privacy: .public)")
    }

    func updateBand(id: UUID, _ transform: (inout EQBand) -> Void) {
        guard let idx = settings.bands.firstIndex(where: { $0.id == id }) else { return }
        // Mutate a local copy and write back ONCE, so settings.didSet (and the
        // full parameter re-push) fires a single time per edit, not twice.
        var band = settings.bands[idx]
        transform(&band)
        settings.bands[idx] = band.clamped()  // clamp so the UI can't push out of range
    }

    // MARK: - Parameter push

    private func onSettingsChanged() {
        persistSettings()
        applyAllParameters()
    }

    /// Pushes the full settings state into the AudioUnit (and the snapshot the
    /// tap reads when building a new unit). Safe to call when no unit exists yet
    /// — the snapshot is still stored for the next `prepare`.
    func applyAllParameters() {
        // Build a plain-value snapshot and hand it to the tap context. This
        // also updates the realtime bypass flag.
        let snapshot = makeSnapshot()
        tapContext.updateSnapshot(snapshot)

        let hasLiveUnit = tapContext.audioUnit != nil
        EQLog.controller.log("applyAllParameters: enabled=\(self.settings.enabled, privacy: .public) preamp=\(self.settings.preamp, privacy: .public) bands=\(self.settings.bands.count, privacy: .public) isActive=\(snapshot.isActive, privacy: .public) bypass=\(self.tapContext.bypass, privacy: .public) liveUnit=\(hasLiveUnit, privacy: .public)")
        EQLog.line("controller", "apply: enabled=\(settings.enabled) preamp=\(settings.preamp) bands=\(settings.bands.count) isActive=\(snapshot.isActive) bypass=\(tapContext.bypass) liveUnit=\(hasLiveUnit)")

        // If a unit is live, push every parameter immediately. The band COUNT
        // never changes on the live unit (it always has maxBands bands, unused
        // ones bypassed), so this is a safe realtime parameter update.
        guard let au = tapContext.audioUnit else {
            EQLog.controller.log("applyAllParameters: no live unit yet (snapshot stored for next prepare)")
            return
        }
        EQAudioTap.configureParameters(au, from: snapshot)
    }

    private func makeSnapshot() -> EQParamSnapshot {
        EQParamSnapshot(
            enabled: settings.enabled,
            preamp: Float(settings.preamp),
            bands: settings.bands.prefix(EQSettings.maxBands).map { band in
                EQBandSnapshot(
                    frequency: Float(band.frequency),
                    gain: Float(band.gain),
                    bandwidth: Float(band.bandwidth),
                    filterType: band.filterType.auFilterType,
                    enabled: band.enabled
                )
            }
        )
    }

    // MARK: - Persistence

    private func persistSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: settingsKey)
        }
    }

    private static func loadSettings(defaults: UserDefaults) -> EQSettings {
        guard let data = defaults.data(forKey: "eq.currentSettings"),
              let decoded = try? JSONDecoder().decode(EQSettings.self, from: data)
        else {
            return EQSettings.flat
        }
        return decoded
    }

    private func persistUserPresets() {
        if let data = try? JSONEncoder().encode(userPresets) {
            defaults.set(data, forKey: presetsKey)
        }
    }

    private func loadUserPresets() -> [EQPreset] {
        guard let data = defaults.data(forKey: presetsKey),
              let decoded = try? JSONDecoder().decode([EQPreset].self, from: data)
        else { return [] }
        return decoded
    }
}
