//
//  LibraryShuffler.swift
//  drone
//
//  Created by Anthony on 5/25/26.
//

import Foundation

// MARK: - Protocol

protocol ShuffleStrategy {
    /// Fetches and orders a playback queue for the full library.
    func buildQueue(server: Server) async throws -> [Song]
}

// MARK: - Context / errors

enum LibraryShuffleError: Error, LocalizedError {
    case notImplemented
    case emptyLibrary

    var errorDescription: String? {
        switch self {
        case .notImplemented: return "Shuffle strategy not yet implemented"
        case .emptyLibrary:   return "No songs returned from server"
        }
    }
}

// MARK: - Strategy: ServerRandom
//
// Delegates randomisation entirely to the Subsonic server via getRandomSongs.
// Fast — single request, no local sorting needed.
// Limitation: capped at 500 songs per call; does not guarantee artist spread.

struct ServerRandomStrategy: ShuffleStrategy {
    var size: Int = 500

    func buildQueue(server: Server) async throws -> [Song] {
        let response = try await server.getRandomSongs(size: size)
        let songs = response.song.map(\.toSong)
        guard !songs.isEmpty else { throw LibraryShuffleError.emptyLibrary }
        return songs
    }
}

// MARK: - Strategy: SpreadShuffle  (not yet implemented)
//
// Goal: produce a queue where the same artist never appears within
// `minArtistGap` positions of themselves, while still feeling random.
//
// Algorithm sketch:
//   1. Fetch the full library in pages via search3 (paginated, no size cap).
//   2. Partition songs into per-artist buckets.
//   3. Shuffle within each bucket (Fisher-Yates).
//   4. Interleave buckets with a max-heap ordered by remaining-song-count so
//      artists with more songs get more frequent picks — equivalent to the
//      "reorganise string / task scheduler" problem from CS.
//   5. After interleaving, verify the minArtistGap constraint; if any
//      violation remains (possible when one artist dominates), shift that
//      song forward to the next valid slot using a greedy scan.
//
// Tuning knobs:
//   - minArtistGap   : hard minimum positions between same-artist songs
//   - pageBatchSize  : how many songs to fetch per search3 page

struct SpreadShuffleStrategy: ShuffleStrategy {
    var minArtistGap: Int = 4
    var pageBatchSize: Int = 500

    func buildQueue(server: Server) async throws -> [Song] {
        // Step 1 — fetch full library
        var all: [Song] = []
        var offset = 0
        while true {
            let page = try await server.search3(
                songCount: pageBatchSize,
                songOffset: offset
            )
            let songs = page.song.map(\.toSong)
            all.append(contentsOf: songs)
            if songs.count < pageBatchSize { break }
            offset += pageBatchSize
        }
        guard !all.isEmpty else { throw LibraryShuffleError.emptyLibrary }

        // Steps 2–5: artist-spread interleaving
        // TODO: implement heap-based interleave + gap-repair pass
        throw LibraryShuffleError.notImplemented
    }
}

// MARK: - LibraryShuffler

/// Stateless coordinator — swap `strategy` to change the algorithm at runtime.
struct LibraryShuffler {
    var strategy: any ShuffleStrategy = ServerRandomStrategy()

    func shuffle(server: Server) async throws -> [Song] {
        try await strategy.buildQueue(server: server)
    }
}

// MARK: - SongResponse → Song mapping

extension SongResponse {
    var toSong: Song {
        Song(
            songID: id,
            parent: parent ?? "",
            title: title,
            album: album ?? "",
            artist: artist,
            isDir: isDir,
            coverArt: coverArt ?? "",
            created: created ?? "",
            duration: duration ?? 0,
            bitRate: bitRate ?? 0,
            track: track ?? 0,
            year: year ?? 0,
            genre: genre ?? "",
            size: size ?? 0,
            suffix: suffix ?? "",
            contentType: contentType ?? "",
            isVideo: isVideo ?? false,
            path: path ?? "",
            albumId: albumId ?? "",
            artistId: artistId ?? "",
            type: type ?? "",
            discNumber: discNumber ?? 0
        )
    }
}
