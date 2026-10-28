//
//  AlbumContextMenu.swift
//  drone
//
//  Shared album actions + menu UI. Used by both the right-click context menu
//  on album cards (albums grid / recently added) and the ellipsis (•••) menu
//  in the album detail view, so the action logic lives in exactly one place.
//

import SwiftData
import SwiftUI

// MARK: - Shared actions

/// Encapsulates the "what happens when you pick an album menu item" logic so
/// the context menu and the detail-view ellipsis menu share one implementation.
///
/// Value type holding the album plus the dependencies the actions need; views
/// construct it from their environment and pass it to `albumMenuButtons`.
@MainActor
struct AlbumActions {
    let album: Album
    let server: Server
    let player: APlayer
    let router: NavigationRouter
    let modelContext: ModelContext

    // MARK: Playback

    func play() {
        loadSongs { songs in
            guard !songs.isEmpty else { return }
            player.playAlbum(songs: songs, startingAt: 0)
        }
    }

    func shuffle() {
        loadSongs { songs in
            guard !songs.isEmpty else { return }
            player.shuffleAlbum(songs)
        }
    }

    func playNext() {
        loadSongs { songs in
            // addNext inserts right after the current track, so inserting in
            // reverse preserves album order.
            for song in songs.reversed() {
                player.addNext(song: song)
            }
        }
    }

    func addToQueue() {
        loadSongs { songs in
            for song in songs {
                player.addToQueue(song: song)
            }
        }
    }

    // MARK: Navigation

    func navigateToArtist() {
        let id = album.artistId
        guard !id.isEmpty else { return }
        let descriptor = FetchDescriptor<Artist>(
            predicate: #Predicate { $0.artistID == id }
        )
        guard let artist = (try? modelContext.fetch(descriptor))?.first else { return }
        router.navigate(to: artist)
    }

    // MARK: Helpers

    /// Fetches the album's songs (track-ordered) and hands them to `completion`
    /// on the main actor. Failures are logged and yield no action.
    private func loadSongs(_ completion: @escaping ([Song]) -> Void) {
        let albumId = album.albumId
        let server = server
        Task { @MainActor in
            do {
                let response = try await server.getAlbum(albumId: albumId)
                let mapped: [Song] = response.song.map { Song(response: $0) }
                let songs: [Song] = mapped.sorted { lhs, rhs in
                    if lhs.discNumber == rhs.discNumber {
                        return lhs.track < rhs.track
                    }
                    return lhs.discNumber < rhs.discNumber
                }
                completion(songs)
            } catch {
                Server.logger.error(
                    "Album menu: failed to load songs: \(error.localizedDescription)"
                )
            }
        }
    }
}

// MARK: - Shared menu buttons

/// The menu items shown by both the album context menu and the ellipsis menu.
/// Centralised so the two entry points can never drift apart.
@ViewBuilder
func albumMenuButtons(
    _ actions: AlbumActions,
    includeGoToArtist: Bool = true
) -> some View {
    Button { actions.play() } label: {
        Label("Play", systemImage: "play.fill")
    }
    Button { actions.shuffle() } label: {
        Label("Shuffle", systemImage: "shuffle")
    }
    Divider()
    Button { actions.playNext() } label: {
        Label("Play Next", systemImage: "arrow.forward.to.line")
    }
    Button { actions.addToQueue() } label: {
        Label("Add to Queue", systemImage: "text.badge.plus")
    }
    if includeGoToArtist {
        Divider()
        Button { actions.navigateToArtist() } label: {
            Label("Go to Artist", systemImage: "music.mic")
        }
    }
}

// MARK: - Right-click context menu modifier

private struct AlbumContextMenuModifier: ViewModifier {
    let album: Album
    @EnvironmentObject var server: Server
    @EnvironmentObject var player: APlayer
    @EnvironmentObject var router: NavigationRouter
    @Environment(\.modelContext) private var modelContext

    func body(content: Content) -> some View {
        content.contextMenu {
            albumMenuButtons(
                AlbumActions(
                    album: album,
                    server: server,
                    player: player,
                    router: router,
                    modelContext: modelContext
                )
            )
        }
    }
}

extension View {
    func albumContextMenu(album: Album) -> some View {
        modifier(AlbumContextMenuModifier(album: album))
    }
}
