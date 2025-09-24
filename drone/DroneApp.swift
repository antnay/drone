//
//  DroneApp.swift
//  drone
//
//  Created by Anthony on 9/4/25.
//

import SwiftUI

@main
struct droneApp: App {
    @State var server: Server = Server()
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        Settings {
            SourceView(server: $server)
        }
        .defaultSize(width: 200, height: 200)
    }
}
