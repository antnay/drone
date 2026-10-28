//
//  EQModels.swift
//  drone
//
//  Data model for the parametric equalizer. Pure value types, Codable for
//  JSON persistence in UserDefaults. The DSP mapping onto Apple's AUNBandEQ
//  lives in EqualizerController.
//

import AudioToolbox
import Foundation

// MARK: - Filter type

/// Band filter shapes, mapped 1:1 onto AUNBandEQ's filter type enum.
enum EQFilterType: Int, Codable, CaseIterable, Identifiable {
    case parametric          // peak/notch (the classic parametric band)
    case lowShelf
    case highShelf
    case resonantLowPass
    case resonantHighPass
    case bandPass
    case bandStop
    case resonantLowShelf
    case resonantHighShelf

    var id: Int { rawValue }

    /// The matching `AUNBandEQFilterType` raw value.
    var auFilterType: Int {
        switch self {
        case .parametric:        return Int(kAUNBandEQFilterType_Parametric)
        case .lowShelf:          return Int(kAUNBandEQFilterType_LowShelf)
        case .highShelf:         return Int(kAUNBandEQFilterType_HighShelf)
        case .resonantLowPass:   return Int(kAUNBandEQFilterType_ResonantLowPass)
        case .resonantHighPass:  return Int(kAUNBandEQFilterType_ResonantHighPass)
        case .bandPass:          return Int(kAUNBandEQFilterType_BandPass)
        case .bandStop:          return Int(kAUNBandEQFilterType_BandStop)
        case .resonantLowShelf:  return Int(kAUNBandEQFilterType_ResonantLowShelf)
        case .resonantHighShelf: return Int(kAUNBandEQFilterType_ResonantHighShelf)
        }
    }

    var displayName: String {
        switch self {
        case .parametric:        return "Parametric"
        case .lowShelf:          return "Low Shelf"
        case .highShelf:         return "High Shelf"
        case .resonantLowPass:   return "Res. Low Pass"
        case .resonantHighPass:  return "Res. High Pass"
        case .bandPass:          return "Band Pass"
        case .bandStop:          return "Band Stop"
        case .resonantLowShelf:  return "Res. Low Shelf"
        case .resonantHighShelf: return "Res. High Shelf"
        }
    }

    /// Whether this filter shape responds to the Gain parameter (pass/stop
    /// filters don't apply gain in AUNBandEQ).
    var usesGain: Bool {
        switch self {
        case .parametric, .lowShelf, .highShelf,
             .resonantLowShelf, .resonantHighShelf:
            return true
        default:
            return false
        }
    }
}

// MARK: - Band

struct EQBand: Identifiable, Codable, Equatable {
    let id: UUID
    var frequency: Double   // Hz (20...20000)
    var gain: Double        // dB (-24...+24)
    var bandwidth: Double   // octaves (AUNBandEQ "Bandwidth"; ~0.05...5.0)
    var filterType: EQFilterType
    var enabled: Bool

    init(
        id: UUID = UUID(),
        frequency: Double,
        gain: Double = 0,
        bandwidth: Double = 0.5,
        filterType: EQFilterType = .parametric,
        enabled: Bool = true
    ) {
        self.id = id
        self.frequency = frequency
        self.gain = gain
        self.bandwidth = bandwidth
        self.filterType = filterType
        self.enabled = enabled
    }

    static let minFrequency: Double = 20
    static let maxFrequency: Double = 20_000
    static let minGain: Double = -24
    static let maxGain: Double = 24
    static let minBandwidth: Double = 0.05
    static let maxBandwidth: Double = 5.0

    /// Returns a copy with every parameter forced into its valid range and any
    /// NaN/infinite values sanitised. This is the single guard that prevents
    /// degenerate / out-of-range bands no matter how the UI drives edits.
    func clamped() -> EQBand {
        var b = self
        b.frequency = EQBand.sanitize(frequency, EQBand.minFrequency, EQBand.maxFrequency, fallback: 1000)
        b.gain = EQBand.sanitize(gain, EQBand.minGain, EQBand.maxGain, fallback: 0)
        b.bandwidth = EQBand.sanitize(bandwidth, EQBand.minBandwidth, EQBand.maxBandwidth, fallback: 0.5)
        return b
    }

    private static func sanitize(_ value: Double, _ lo: Double, _ hi: Double, fallback: Double) -> Double {
        guard value.isFinite else { return fallback }
        return min(hi, max(lo, value))
    }
}

// MARK: - Settings

struct EQSettings: Codable, Equatable {
    var enabled: Bool
    var preamp: Double      // global gain, dB (-24...+24)
    var bands: [EQBand]

    /// AUNBandEQ supports up to a fixed maximum number of bands.
    static let maxBands = 16

    init(enabled: Bool = false, preamp: Double = 0, bands: [EQBand] = []) {
        self.enabled = enabled
        self.preamp = preamp
        self.bands = bands
    }

    /// Neutral default: EQ off, no preamp, and the standard ISO band layout all
    /// at 0 dB (a flat line with the familiar ~10 nodes visible).
    static var flat: EQSettings {
        EQSettings(enabled: false, preamp: 0, bands: EQPreset.flatBands)
    }
}

// MARK: - Preset

struct EQPreset: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var settings: EQSettings

    init(
        id: UUID = UUID(),
        name: String,
        settings: EQSettings
    ) {
        self.id = id
        self.name = name
        self.settings = settings
    }

    // MARK: Default band layout

    /// Standard 10-band ISO graphic-EQ frequency layout. This is the default
    /// *band* set (not a named preset) shown when the EQ opens and restored on
    /// Reset — all at 0 dB, so the curve is flat but the nodes are visible.
    static let standardFrequencies: [Double] =
        [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]

    static var flatBands: [EQBand] {
        standardFrequencies.map { EQBand(frequency: $0, gain: 0) }
    }
}
