//
//  StreamingSettings.swift
//  drone
//
//  User-selectable streaming audio quality: transcoding codec (Subsonic
//  `format`) and bitrate cap (Subsonic `maxBitRate`). Persisted app-wide in
//  UserDefaults. Defaults to raw/unlimited so behaviour is lossless until the
//  user opts into transcoding (which also protects the EQ's source quality).
//

import Combine
import Foundation

struct StreamingSettings: Codable, Equatable {
    /// Subsonic `format` value: "raw", "mp3", "opus", "aac", "ogg", "flac", "wav".
    var format: String
    /// Subsonic `maxBitRate` in kbps. 0 = unlimited. Ignored when format=raw.
    var maxBitRate: Int

    init(format: String = "raw", maxBitRate: Int = 0) {
        self.format = format
        self.maxBitRate = maxBitRate
    }

    static let `default` = StreamingSettings()

    /// Available codecs, in display order. "raw" means original file, no
    /// transcoding.
    static let formatOptions: [(value: String, label: String)] = [
        ("raw", "Original (no transcoding)"),
        ("mp3", "MP3"),
        ("opus", "Opus"),
        ("aac", "AAC"),
        ("ogg", "Ogg Vorbis"),
        ("flac", "FLAC (lossless)"),
        ("wav", "WAV (lossless)"),
    ]

    /// Available bitrate caps in kbps; 0 = unlimited.
    static let bitRateOptions: [Int] = [0, 64, 96, 128, 192, 256, 320]

    static func bitRateLabel(_ kbps: Int) -> String {
        kbps == 0 ? "Unlimited" : "\(kbps) kbps"
    }

    /// True when a bitrate cap is meaningful (transcoding formats only).
    var bitRateApplies: Bool { format != "raw" }
}

/// App-wide store for streaming settings, persisted to UserDefaults as JSON.
/// `streamURL` reads the persisted value directly so it stays correct even
/// without injection; the UI binds to this observable copy.
@MainActor
final class StreamingSettingsStore: ObservableObject {
    static let defaultsKey = "streaming.settings"

    @Published var settings: StreamingSettings {
        didSet { persist() }
    }

    init() {
        self.settings = StreamingSettingsStore.load()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }

    /// Reads the persisted settings (used by both the store and streamURL).
    /// nonisolated: pure UserDefaults read, safe to call from any context.
    nonisolated static func load() -> StreamingSettings {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode(StreamingSettings.self, from: data)
        else { return .default }
        return decoded
    }
}
