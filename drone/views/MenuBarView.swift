import SwiftData
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var player: APlayer
    @EnvironmentObject var router: NavigationRouter
    @Environment(\.openWindow) private var openWindow
    @Environment(\.modelContext) private var modelContext
    @State private var showQueue = false

    private var nextSongs: ArraySlice<Song> {
        let start = player.curIndex + 1
        guard start < player.queue.count else { return [] }
        return player.queue[start..<min(start + 5, player.queue.count)]
    }

    var body: some View {
        VStack(spacing: 0) {
            playerRow
                .padding(12)

            if showQueue && !nextSongs.isEmpty {
                Divider()
                upNextSection
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
            }
        }
        .frame(width: 340)
    }

    // MARK: - Player row

    private var playerRow: some View {
        HStack(spacing: 10) {
            artButton
            trackInfo
            Spacer(minLength: 0)
            controls
            queueToggle
        }
    }

    private var artButton: some View {
        Button(action: { show(); navigateToAlbum() }) {
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.secondary.opacity(0.12))
                if let image = player.nowPlayingImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
            }
            .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .disabled(player.current == nil)
    }

    private var trackInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Button(action: { show(); navigateToAlbum() }) {
                Text(player.current?.title ?? "Not Playing")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .buttonStyle(.plain)

            Button(action: { show(); navigateToArtist() }) {
                Text(player.current?.artist ?? " ")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .buttonStyle(.plain)

            Button(action: { show(); navigateToAlbum() }) {
                Text(player.current?.album ?? " ")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: 140, alignment: .leading)
    }

    private var controls: some View {
        HStack(spacing: 18) {
            Button(action: { player.back() }) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
            .disabled(player.curIndex == 0)

            Button(action: {
                player.isPlaying ? player.pause() : player.resume()
            }) {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 20))
            }
            .buttonStyle(.plain)
            .disabled(player.current == nil)

            Button(action: { player.forward() }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
            .disabled(player.curIndex + 1 >= player.queue.count)
        }
    }

    private var queueToggle: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.18)) { showQueue.toggle() }
        }) {
            Image(systemName: "list.bullet")
                .font(.system(size: 13))
                .foregroundStyle(showQueue ? Color.accentColor : .secondary)
        }
        .buttonStyle(.plain)
        .disabled(nextSongs.isEmpty)
    }

    // MARK: - Up next section

    private var upNextSection: some View {
        VStack(spacing: 0) {
            Text("Up Next")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
                .padding(.bottom, 4)

            ForEach(Array(nextSongs.enumerated()), id: \.offset) { offset, song in
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(song.title)
                            .font(.system(size: 12))
                            .lineLimit(1)
                        Text(song.artist)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)

                if offset < nextSongs.count - 1 {
                    Divider().opacity(0.15)
                }
            }
        }
    }

    // MARK: - Helpers

    private func show() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { !($0 is NSPanel) && $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: "main")
        }
    }

    private func navigateToAlbum() {
        guard let albumId = player.current?.albumId, !albumId.isEmpty else { return }
        let descriptor = FetchDescriptor<Album>(
            predicate: #Predicate { $0.albumId == albumId }
        )
        guard let album = (try? modelContext.fetch(descriptor))?.first else { return }
        router.navigate(to: album)
    }

    private func navigateToArtist() {
        guard let artistId = player.current?.artistId, !artistId.isEmpty else { return }
        let descriptor = FetchDescriptor<Artist>(
            predicate: #Predicate { $0.artistID == artistId }
        )
        guard let artist = (try? modelContext.fetch(descriptor))?.first else { return }
        router.navigate(to: artist)
    }
}
