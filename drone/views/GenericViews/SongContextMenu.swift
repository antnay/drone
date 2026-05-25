import SwiftData
import SwiftUI

// MARK: - Ellipsis menu button

struct SongMenuButton: View {
    let song: Song
    var font: Font = .system(size: 12)
    @EnvironmentObject var player: APlayer
    @EnvironmentObject var router: NavigationRouter
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Menu {
            menuContent
        } label: {
            Image(systemName: "ellipsis")
                .font(font)
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 24)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    @ViewBuilder
    private var menuContent: some View {
        Button { player.addNext(song: song) } label: {
            Label("Play Next", systemImage: "arrow.forward.to.line")
        }
        Button { player.addToQueue(song: song) } label: {
            Label("Add to Queue", systemImage: "text.badge.plus")
        }
        Divider()
        Button { navigateToAlbum() } label: {
            Label("Go to Album", systemImage: "square.stack")
        }
        Button { navigateToArtist() } label: {
            Label("Go to Artist", systemImage: "music.mic")
        }
    }

    private func navigateToAlbum() {
        let id = song.albumId
        guard !id.isEmpty else { return }
        let d = FetchDescriptor<Album>(predicate: #Predicate { $0.albumId == id })
        guard let album = (try? modelContext.fetch(d))?.first else { return }
        router.navigate(to: album)
    }

    private func navigateToArtist() {
        let id = song.artistId
        guard !id.isEmpty else { return }
        let d = FetchDescriptor<Artist>(predicate: #Predicate { $0.artistID == id })
        guard let artist = (try? modelContext.fetch(d))?.first else { return }
        router.navigate(to: artist)
    }
}

// MARK: - Right-click context menu modifier

private struct SongContextMenuModifier: ViewModifier {
    let song: Song
    @EnvironmentObject var player: APlayer
    @EnvironmentObject var router: NavigationRouter
    @Environment(\.modelContext) private var modelContext

    func body(content: Content) -> some View {
        content.contextMenu {
            Button { player.addNext(song: song) } label: {
                Label("Play Next", systemImage: "arrow.forward.to.line")
            }
            Button { player.addToQueue(song: song) } label: {
                Label("Add to Queue", systemImage: "text.badge.plus")
            }
            Divider()
            Button { navigateToAlbum() } label: {
                Label("Go to Album", systemImage: "square.stack")
            }
            Button { navigateToArtist() } label: {
                Label("Go to Artist", systemImage: "music.mic")
            }
        }
    }

    private func navigateToAlbum() {
        let id = song.albumId
        guard !id.isEmpty else { return }
        let d = FetchDescriptor<Album>(predicate: #Predicate { $0.albumId == id })
        guard let album = (try? modelContext.fetch(d))?.first else { return }
        router.navigate(to: album)
    }

    private func navigateToArtist() {
        let id = song.artistId
        guard !id.isEmpty else { return }
        let d = FetchDescriptor<Artist>(predicate: #Predicate { $0.artistID == id })
        guard let artist = (try? modelContext.fetch(d))?.first else { return }
        router.navigate(to: artist)
    }
}

extension View {
    func songContextMenu(song: Song) -> some View {
        modifier(SongContextMenuModifier(song: song))
    }

    /// Clears hover state on rightMouseDown, before the context menu appears.
    /// Needed because macOS suspends NSTrackingArea events while a context menu
    /// is open, so onHover(false) never fires for the previously hovered row.
    func clearHoverOnRightClick(_ action: @escaping () -> Void) -> some View {
        modifier(ClearHoverOnRightClickModifier(action: action))
    }
}

private struct ClearHoverOnRightClickModifier: ViewModifier {
    let action: () -> Void
    @State private var monitor: Any?

    func body(content: Content) -> some View {
        content
            .onAppear {
                monitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { event in
                    action()
                    return event
                }
            }
            .onDisappear {
                if let m = monitor { NSEvent.removeMonitor(m) }
                monitor = nil
            }
    }
}
