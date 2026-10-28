//
//  SearchResultsView.swift
//  drone
//
//  Created by Anthony on 10/25/26.
//

import SwiftData
import SwiftUI

struct SearchResultsView: View {
    @Binding var searchText: String

    @EnvironmentObject var server: Server
    @EnvironmentObject var player: APlayer
    @EnvironmentObject var router: NavigationRouter

    @Query(sort: \Artist.name) private var allArtists: [Artist]
    @Query(sort: \Album.name) private var allAlbums: [Album]

    @State private var songs: [Song] = []
    @State private var isSearchingSongs = false

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var matchedArtists: [Artist] {
        let q = trimmedQuery
        guard !q.isEmpty else { return [] }
        return allArtists.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    private var matchedAlbums: [Album] {
        let q = trimmedQuery
        guard !q.isEmpty else { return [] }
        return allAlbums.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    private var hasAnyResult: Bool {
        !matchedArtists.isEmpty || !matchedAlbums.isEmpty || !songs.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Results for \u{201C}\(trimmedQuery)\u{201D}")
                    .font(.system(size: 22, weight: .bold))
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 16)

                if trimmedQuery.isEmpty {
                    emptyState("Type to search your library")
                } else if !hasAnyResult && !isSearchingSongs {
                    emptyState("No results found")
                } else {
                    artistsSection
                    albumsSection
                    songsSection
                }
            }
        }
        .task(id: searchText) {
            await searchSongs()
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var artistsSection: some View {
        if !matchedArtists.isEmpty {
            sectionHeader("Artists")
            LazyVStack(spacing: 0) {
                ForEach(matchedArtists) { artist in
                    artistRow(artist)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    @ViewBuilder
    private var albumsSection: some View {
        if !matchedAlbums.isEmpty {
            sectionHeader("Albums")
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 160), spacing: 16)],
                spacing: 16
            ) {
                ForEach(matchedAlbums) { album in
                    AlbumCard(album: album) { navigate(to: album) }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    @ViewBuilder
    private var songsSection: some View {
        if isSearchingSongs || !songs.isEmpty {
            sectionHeader("Songs")
            if isSearchingSongs && songs.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(songs.enumerated()), id: \.element.id) {
                        index,
                        song in
                        songRow(song: song, index: index)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Rows

    private func artistRow(_ artist: Artist) -> some View {
        Button(action: { navigate(to: artist) }) {
            HStack {
                Text(artist.name)
                    .font(.system(size: 14))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) { Divider().opacity(0.15) }
    }

    private func navigate(to album: Album) {
        searchText = ""
        router.navigate(to: album)
    }

    private func navigate(to artist: Artist) {
        searchText = ""
        router.navigate(to: artist)
    }

    private func songRow(song: Song, index: Int) -> some View {
        let isCurrent = song.songID == player.current?.songID
        return Button(action: {
            player.playAlbum(songs: songs, startingAt: index)
        }) {
            HStack(spacing: 16) {
                ZStack {
                    if isCurrent {
                        Image(systemName: "waveform")
                            .font(.system(size: 12))
                            .foregroundStyle(.accent)
                            .symbolEffect(
                                .variableColor.iterative,
                                isActive: player.isPlaying
                            )
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 20, alignment: .center)

                VStack(alignment: .leading, spacing: 2) {
                    Text(song.title)
                        .font(.system(size: 13, weight: isCurrent ? .semibold : .regular))
                        .foregroundStyle(isCurrent ? Color.accentColor : .primary)
                        .lineLimit(1)
                    Text("\(song.artist)\(song.album.isEmpty ? "" : " · \(song.album)")")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                SongMenuButton(song: song, font: .system(size: 14))
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isCurrent ? Color.accentColor.opacity(0.08) : .clear)
        .songContextMenu(song: song)
        .overlay(alignment: .bottom) {
            if index < songs.count - 1 {
                Divider().opacity(0.12)
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 16, weight: .semibold))
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
    }

    private func emptyState(_ message: String) -> some View {
        Text(message)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 200, alignment: .center)
    }

    private func searchSongs() async {
        let query = trimmedQuery
        guard !query.isEmpty else {
            songs = []
            isSearchingSongs = false
            return
        }

        // Debounce: wait briefly; a new keystroke cancels this task (id change).
        do {
            try await Task.sleep(nanoseconds: 300_000_000)
        } catch {
            return
        }

        isSearchingSongs = true

        do {
            let result = try await server.search3(query: query)
            guard !Task.isCancelled else { return }
            songs = result.song.map(\.toSong)
            isSearchingSongs = false
        } catch {
            guard !Task.isCancelled else { return }
            Server.logger.error(
                "Song search failed: \(error.localizedDescription)"
            )
            songs = []
            isSearchingSongs = false
        }
    }
}
