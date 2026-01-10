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
            Tab("Source", systemImage: "network") {
                SourceView()
            }
        }
        .frame(width: 1000, height: 500, alignment: .center)
    }
}
