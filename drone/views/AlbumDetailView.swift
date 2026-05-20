//
//  AlbumDetailView.swift
//  drone
//
//  Created by Anthony on 5/19/26.
//

import SwiftUI

struct AlbumDetailView: View {
    @EnvironmentObject var server: Server
    @EnvironmentObject var player: APlayer
    let album: Album
    @State private var songs: [Song] = []
    @State private var isLoading = true
    @State private var image: NSImage?
    @State private var hoveredSongID: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 20)

                Divider().opacity(0.3)

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    songList
                }
            }
        }
        .task {
            await loadAlbum()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 24) {
            // Cover art
            ZStack {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.secondary.opacity(0.15))
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary.opacity(0.3))
                        )
                }
            }
            .frame(width: 280, height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        Color(nsColor: .gray),
//                        LinearGradient(
//                            colors: [
//                                Color.white.opacity(0.5),
//                                Color.white.opacity(0.15),
//                                Color.black.opacity(0.1),
//                                Color.white.opacity(0.2),
//                            ],
//                            startPoint: .topLeading,
//                            endPoint: .bottomTrailing
//                        ),
                        lineWidth: 0.35
                    )
            )
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)

            // Album info
            VStack(alignment: .leading, spacing: 2) {
                Text(album.name)
                    .font(.system(size: 24, weight: .semibold))
                    .lineLimit(2)

                Text(album.artist)
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(.accent)

                HStack(spacing: 4) {
                    if !album.genre.isEmpty {
                        Text(album.genre)
                    }
                    if album.year > 0 {
                        if !album.genre.isEmpty { Text("·") }
                        Text(album.year.description)
                    }
                    if !songs.isEmpty {
                        Text("·")
                        Text("\(songs.count) songs, \(formattedTotalDuration)")
                    }
                }
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

                Spacer().frame(height: 12)

                HStack(spacing: 12) {
                    Button(action: { player.play() }) {
                        Label("Play", systemImage: "play.fill")
                    }
                    .buttonStyle(PillButtonStyle())
                    Button(action: { player.shuffleAlbum(songs) }) {
                        Label("Shuffle", systemImage: "shuffle")
                    }
                    .buttonStyle(PillButtonStyle())
                }
            }
        }
    }
    // MARK: - Song List

    private var songList: some View {
        VStack(spacing: 0) {
            ForEach(Array(songs.enumerated()), id: \.element.id) {
                index,
                song in
                songRow(song: song, index: index)
            }
        }
        .padding(.horizontal, 24)
    }

    private func songRow(song: Song, index: Int) -> some View {
        Button(action: { player.playAlbum(songs: songs, startingAt: index) }) {
            HStack(spacing: 16) {
                // Track number or play icon on hover
                ZStack {
                    if hoveredSongID == song.songID {
                        Image(systemName: "play.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.accent)
                    } else {
                        Text("\(song.track)")
                            .font(.system(size: 14).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 30, alignment: .trailing)

                Text(song.title)
                    .font(.system(size: 14))
                    .foregroundStyle(
                        hoveredSongID == song.songID ? .accent : .primary
                    )
                    .lineLimit(1)

                Spacer()

                Text(formattedDuration(song.duration))
                    .font(.system(size: 13).monospacedDigit())
                    .foregroundStyle(.secondary)

                Button(action: { /* context menu actions */  }) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .opacity(hoveredSongID == song.songID ? 1 : 0)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredSongID = hovering ? song.songID : nil
        }
        .overlay(alignment: .bottom) {
            if index < songs.count - 1 {
                Divider().opacity(0.2).padding(.leading, 46)
            }
        }
    }

    private func loadAlbum() async {
        // Load cover art
        if !album.coverArt.isEmpty {
            let id = album.coverArt
            if let data = try? await server.getCoverArt(id: id) {
                image = try? await ImageCacheManager.shared.image(
                    for: id,
                    data: data
                )
            }
        }
        // Load songs
        do {
            let response = try await server.getAlbum(albumId: album.albumId)
            songs = response.song.map { s in
                Song(
                    songID: s.id,
                    parent: s.parent ?? "",
                    title: s.title,
                    album: s.album ?? "",
                    artist: s.artist,
                    isDir: s.isDir,
                    coverArt: s.coverArt ?? "",
                    created: s.created ?? "",
                    duration: s.duration ?? 0,
                    bitRate: s.bitRate ?? 0,
                    track: s.track ?? 0,
                    year: s.year ?? 0,
                    genre: s.genre ?? "",
                    size: s.size ?? 0,
                    suffix: s.suffix ?? "",
                    contentType: s.contentType ?? "",
                    isVideo: s.isVideo ?? false,
                    path: s.path ?? "",
                    albumId: s.albumId ?? "",
                    artistId: s.artistId ?? "",
                    type: s.type ?? "",
                    discNumber: s.discNumber ?? 0
                )
            }.sorted {
                $0.discNumber == $1.discNumber
                    ? $0.track < $1.track : $0.discNumber < $1.discNumber
            }
            isLoading = false
        } catch {
            Server.logger.error(
                "Failed to load album: \(error.localizedDescription)"
            )
            isLoading = false
        }
    }

    //    private func playAll() {
    //        player.play(songs: songs, startingAt: 0)
    //    }
    //
    //    private func shuffleAll() {
    //        player.play(songs: songs.shuffled(), startingAt: 0)
    //    }
    //
    //    private func playSong(at index: Int) {
    //        player.play(songs: songs, startingAt: index)
    //    }

    private var formattedTotalDuration: String {
        let total = songs.reduce(0) { $0 + $1.duration }
        let minutes = total / 60
        if minutes >= 60 {
            return "\(minutes / 60) hr \(minutes % 60) min"
        }
        return "\(minutes) min"
    }

    private func formattedDuration(_ seconds: Int) -> String {
        "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }
}

struct PillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 10)
            .frame(width: 104, height: 30)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.accent)
            )
    }
}
