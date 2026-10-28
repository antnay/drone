//
//  DroneApp.swift
//  drone
//
//  Created by Anthony on 9/4/25.
//

import SwiftData
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        if flag {
            return true
        }
        if let window = NSApp.windows.first(where: { !($0 is NSPanel) && $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
            return false
        }
        // No main window survives (can happen once the WindowGroup's scene is
        // fully torn down) — ask a live SwiftUI view to recreate it via openWindow,
        // since AppKit alone isn't guaranteed to restore the WindowGroup here.
        NotificationCenter.default.post(name: .droneReopenRequested, object: nil)
        return false
    }
}

extension Notification.Name {
    static let droneReopenRequested = Notification.Name("droneReopenRequested")
}

@main
struct droneApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let container: ModelContainer
    @StateObject private var server: Server
    @StateObject private var player: APlayer
    @StateObject private var router: NavigationRouter = NavigationRouter()

    /// Identifier AppKit uses to persist the main window's frame in UserDefaults.
    private static let mainWindowAutosaveName = "drone.main.window"

    /// Scene id for the Equalizer window.
    static let eqWindowID = "equalizer"

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
        WindowGroup(id: "main") {
            ContentView()
                .environmentObject(server)
                .environmentObject(player)
                .environmentObject(router)
                .modelContainer(container)
                .onAppear {
                    if let window = NSApplication.shared.windows.first(where: { !($0 is NSPanel) }) {
                        window.backgroundColor = .background
                        // Persist the window frame across close/reopen (and
                        // across launches). AppKit stores it in UserDefaults
                        // and restores it whenever a window adopts this name,
                        // including when the WindowGroup scene is recreated.
                        if window.frameAutosaveName != Self.mainWindowAutosaveName {
                            window.setFrameAutosaveName(Self.mainWindowAutosaveName)
                        }
                        window.makeKeyAndOrderFront(nil)
                    }
                }
        }
        .defaultSize(width: 1100, height: 800)
        .commands {
            CommandGroup(after: .appInfo) {
                EqualizerMenuCommand()
            }
        }

        Window("Equalizer", id: Self.eqWindowID) {
            EqualizerView()
                .environmentObject(player)
                .environmentObject(player.equalizer)
                .environmentObject(router)
                .environmentObject(server)
                .modelContainer(container)
        }
        .defaultSize(width: 760, height: 560)
        .windowResizability(.contentMinSize)

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

        MenuBarExtra("Drone", systemImage: "music.note") {
            MenuBarView()
                .environmentObject(server)
                .environmentObject(player)
                .environmentObject(router)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Menu command that opens/focuses the Equalizer window. Lives in a View so it
/// can access the `openWindow` environment action.
private struct EqualizerMenuCommand: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Equalizer…") {
            openWindow(id: droneApp.eqWindowID)
        }
        .keyboardShortcut("e", modifiers: [.command, .option])
    }
}
