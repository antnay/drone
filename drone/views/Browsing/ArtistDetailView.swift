import SwiftData
import SwiftUI

struct ArtistDetailView: View {
    @EnvironmentObject var server: Server
    @EnvironmentObject var player: APlayer
    @Environment(\.modelContext) private var modelContext
    let artist: Artist
    @Query private var albums: [Album]

    init(artist: Artist) {
        self.artist = artist
        let id = artist.artistID
        _albums = Query(
            filter: #Predicate<Album> { $0.artistId == id },
            sort: [SortDescriptor(\.year, order: .reverse)]
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero
                albumsSection
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.35),
                    Color.accentColor.opacity(0.08),
                    Color.clear,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(maxWidth: .infinity)
            .frame(height: 220)

            VStack(alignment: .leading, spacing: 8) {
                Text(artist.name)
                    .font(.system(size: 48, weight: .bold))
                    .lineLimit(2)

                if !albums.isEmpty {
                    Text("\(albums.count) album\(albums.count == 1 ? "" : "s")")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }

                actionBar
                    .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button(action: { playAll() }) {
                Label("Play", systemImage: "play.fill")
            }
            .buttonStyle(PillButtonStyle())
            .disabled(albums.isEmpty)

            Button(action: { shuffleAll() }) {
                Label("Shuffle", systemImage: "shuffle")
            }
            .buttonStyle(PillButtonStyle())
            .disabled(albums.isEmpty)
        }
    }

    // MARK: - Albums grid

    private var albumsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Discography")
                .font(.system(size: 22, weight: .bold))
                .padding(.top, 24)

            if albums.isEmpty {
                Text("No albums in library")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 160), spacing: 16)],
                    spacing: 16
                ) {
                    ForEach(albums) { album in
                        AlbumCard(album: album)
                    }
                }
            }
        }
    }

    // MARK: - Playback

    private func playAll() {
        Task {
            var songs: [Song] = []
            for album in albums.sorted(by: { $0.year < $1.year }) {
                let response = try? await server.getAlbum(albumId: album.albumId)
                songs.append(contentsOf: response?.song.map(\.toSong) ?? [])
            }
            guard !songs.isEmpty else { return }
            player.playAlbum(songs: songs, startingAt: 0)
        }
    }

    private func shuffleAll() {
        Task {
            var songs: [Song] = []
            for album in albums {
                let response = try? await server.getAlbum(albumId: album.albumId)
                songs.append(contentsOf: response?.song.map(\.toSong) ?? [])
            }
            guard !songs.isEmpty else { return }
            player.shuffleAlbum(songs)
        }
    }
}
