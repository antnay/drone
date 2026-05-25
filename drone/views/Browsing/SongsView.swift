//
//  SongsView.swift
//  drone
//
//  Created by Anthony on 9/4/25.
//

import SwiftUI

struct SongsView: View {
    @EnvironmentObject var server: Server
    @EnvironmentObject var player: APlayer
    @State private var songs: [Song] = []
    @State private var isLoading = false
    @State private var hasMore = true
    @State private var offset = 0
    @State private var hoveredSongID: String?
    private let pageSize = 100

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                actionBar
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)

                Divider().opacity(0.3)

                columnHeader
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)

                Divider().opacity(0.15)

                if songs.isEmpty && isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                            songRow(song: song, index: index)
                                .onAppear {
                                    if song.id == songs.last?.id {
                                        loadMore()
                                    }
                                }
                        }
                        if isLoading && !songs.isEmpty {
                            ProgressView()
                                .frame(maxWidth: .infinity, minHeight: 52)
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
        .clearHoverOnRightClick { hoveredSongID = nil }
        .task { loadMore() }
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button(action: { player.playAlbum(songs: songs, startingAt: 0) }) {
                Label("Play", systemImage: "play.fill")
            }
            .buttonStyle(PillButtonStyle())
            .disabled(songs.isEmpty)

            Button(action: { Task { await player.shuffleLibrary() } }) {
                Group {
                    if player.isShuffling {
                        Label("Shuffling…", systemImage: "shuffle")
                    } else {
                        Label("Shuffle", systemImage: "shuffle")
                    }
                }
            }
            .buttonStyle(PillButtonStyle())
            .disabled(player.isShuffling)

            Spacer()

            if !songs.isEmpty {
                Text("\(songs.count)\(hasMore ? "+" : "") songs")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var columnHeader: some View {
        HStack(spacing: 0) {
            Text("Title")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Artist")
                .frame(width: 180, alignment: .leading)
            Text("Album")
                .frame(width: 200, alignment: .leading)
            Text("Year")
                .frame(width: 52, alignment: .trailing)
            Text("Time")
                .frame(width: 52, alignment: .trailing)
            Spacer().frame(width: 36)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.secondary)
    }

    private func songRow(song: Song, index: Int) -> some View {
        let isHovered = hoveredSongID == song.songID
        return Button(action: { player.playAlbum(songs: songs, startingAt: index) }) {
            HStack(spacing: 0) {
                Text(song.title)
                    .font(.system(size: 13))
                    .foregroundStyle(isHovered ? Color.accentColor : .primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(song.artist)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(width: 180, alignment: .leading)

                Text(song.album)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(width: 200, alignment: .leading)

                Text(song.year > 0 ? song.year.description : "—")
                    .font(.system(size: 13).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 52, alignment: .trailing)

                Text(formattedDuration(song.duration))
                    .font(.system(size: 13).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 52, alignment: .trailing)

                SongMenuButton(song: song)
                    .opacity(isHovered ? 1 : 0)
                    .frame(width: 36, alignment: .center)
            }
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isHovered ? Color.primary.opacity(0.05) : .clear)
        .songContextMenu(song: song)
        .onHover { hovering in
            hoveredSongID = hovering ? song.songID : nil
        }
        .overlay(alignment: .bottom) {
            if index < songs.count - 1 {
                Divider().opacity(0.12)
            }
        }
    }

    private func loadMore() {
        guard !isLoading, hasMore else { return }
        isLoading = true
        Task {
            do {
                let results = try await server.search3(
                    songCount: pageSize,
                    songOffset: offset
                )
                let newSongs = results.song.map { s in
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
                }
                await MainActor.run {
                    songs.append(contentsOf: newSongs)
                    hasMore = newSongs.count == pageSize
                    offset += pageSize
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    Server.logger.error("Failed to load songs: \(error.localizedDescription)")
                    isLoading = false
                }
            }
        }
    }

    private func formattedDuration(_ seconds: Int) -> String {
        "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }
}