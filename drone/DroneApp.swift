//
//  DroneApp.swift
//  drone
//
//  Created by Anthony on 9/4/25.
//

import SwiftData
import SwiftUI

@main
struct droneApp: App {
    let container: ModelContainer
    @StateObject private var server: Server
    @StateObject private var player: APlayer

    init() {
        do {
            let schema = Schema([
                Server.self,
                Artist.self,
                Album.self,
            ])
            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            container = try ModelContainer(
                for: schema,
                configurations: [config]
            )

            let context = container.mainContext
            let fetchRequest = FetchDescriptor<Server>()
            let existingServers = try context.fetch(fetchRequest)

            let srv: Server
            if let firstServer = existingServers.first {
                srv = firstServer
            } else {
                srv = Server()
                context.insert(srv)
            }

            _server = StateObject(wrappedValue: srv)
            _player = StateObject(wrappedValue: APlayer(server: srv))
        } catch {
            fatalError("Could not initialize SwiftData: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(server)
                .environmentObject(player)
                .modelContainer(container)
                .onAppear {
                    if let window = NSApplication.shared.windows.first {
                        window.backgroundColor = .background
                    }
                }
        }
        Settings {
            SettingsView()
                .environmentObject(server)
                .modelContainer(container)
                .onAppear {
                    if let window = NSApplication.shared.windows.first {
                        window.backgroundColor = .background
                    }
                }
        }
        .defaultSize(width: 1000, height: 1000)
    }
}
