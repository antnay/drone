//
//  Settings.swift
//  drone
//
//  Created by Anthony on 9/24/25.
//

import Foundation
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var server: Server

    var body: some View {
        TabView {
            Tab("Connection", systemImage: "network") {
                SourceView()
            }
            Tab("Playback", systemImage: "speaker.wave.2") {
                PlaybackSettingsView()
            }
            // Additional tabs (Behaviors, Appearance, …) go here later.
        }
        .frame(width: 1000, height: 500, alignment: .center)
    }
}
