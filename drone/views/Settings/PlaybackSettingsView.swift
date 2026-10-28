//
//  PlaybackSettingsView.swift
//  drone
//
//  Playback settings tab: streaming audio quality (transcoding codec + bitrate
//  cap). Maps onto Subsonic /rest/stream `format` + `maxBitRate`.
//

import SwiftUI

struct PlaybackSettingsView: View {
    @StateObject private var store = StreamingSettingsStore()

    var body: some View {
        Form {
            Section("Streaming Quality") {
                Picker("Codec", selection: $store.settings.format) {
                    ForEach(StreamingSettings.formatOptions, id: \.value) { option in
                        Text(option.label).tag(option.value)
                    }
                }

                Picker("Max Bitrate", selection: $store.settings.maxBitRate) {
                    ForEach(StreamingSettings.bitRateOptions, id: \.self) { kbps in
                        Text(StreamingSettings.bitRateLabel(kbps)).tag(kbps)
                    }
                }
                .disabled(!store.settings.bitRateApplies)

                Text(caption)
                    .font(Design.Detail.Settings.subtextFont)
                    .foregroundStyle(Design.Detail.Settings.subtextStyle)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .padding(20)
    }

    private var caption: String {
        if store.settings.bitRateApplies {
            return "Audio is transcoded to the selected codec, capped at the chosen bitrate. Changes take effect on the next track."
        }
        return "Raw streams the original file with no transcoding — best quality. The bitrate cap doesn’t apply to raw. Changes take effect on the next track."
    }
}
