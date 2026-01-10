//
//  DroneApp.swift
//  drone
//
//  Created by Anthony on 9/4/25.
//

import SwiftUI
import SwiftData

@main
struct droneApp: App {
    let container: ModelContainer
    @StateObject private var server: Server

    init() {
        do {
            let schema = Schema([
                Server.self,
                Artist.self,
                Album.self,
                Song.self,
            ])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, configurations: [config])
            
            let context = container.mainContext
            let fetchRequest = FetchDescriptor<Server>()
            let existingServers = try context.fetch(fetchRequest)
            
            if let firstServer = existingServers.first {
                _server = StateObject(wrappedValue: firstServer)
            } else {
                let newServer = Server()
                context.insert(newServer)
                _server = StateObject(wrappedValue: newServer)
            }
        } catch {
            fatalError("Could not initialize SwiftData: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(server)
                .modelContainer(container)
        }
        Settings {
            SettingsView()
                .environmentObject(server)
                .modelContainer(container)
        }
        .defaultSize(width: 1000, height: 1000)
    }
}
