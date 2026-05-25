//
//  SubSonicResponse.swift
//  drone
//
//  Created by Anthony on 9/17/25.
//

import Foundation

struct SubsonicResponse<T: Codable>: Codable {
    let status: String
    let version: String
    let type: String
    let serverVersion: String
    let openSubsonic: Bool
    let error: SubsonicError?
    let data: T?

    enum CodingKeys: String, CodingKey {
        case status, version, type, serverVersion, openSubsonic, error
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        status = try container.decode(String.self, forKey: .status)
        version = try container.decode(String.self, forKey: .version)
        type = try container.decode(String.self, forKey: .type)
        serverVersion = try container.decode(
            String.self, forKey: .serverVersion)
        openSubsonic = try container.decode(Bool.self, forKey: .openSubsonic)
        error = try? container.decode(SubsonicError.self, forKey: .error)

        let raw = try decoder.container(keyedBy: DynamicCodingKey.self)
        let known = Set([
            "status", "version", "type", "serverVersion", "openSubsonic",
            "error",
        ])

        var found: T? = nil
        for key in raw.allKeys {
            if known.contains(key.stringValue) { continue }
            found = try? raw.decode(T.self, forKey: key)
            if found != nil { break }
        }
        data = found
    }

}

struct TopLevel<T: Codable>: Codable {
    let subsonicResponse: SubsonicResponse<T>

    enum CodingKeys: String, CodingKey {
        case subsonicResponse = "subsonic-response"
    }
}

struct SubsonicError: Codable {
    let code: Int
    let message: String
}

struct DynamicCodingKey: CodingKey {
    var stringValue: String
    init?(stringValue: String) { self.stringValue = stringValue }
    var intValue: Int? { nil }
    init?(intValue: Int) { nil }
}

struct PingResponse: Codable {
}

struct ArtistsResponse: Codable {
    let index: [ArtistIndex]
}

struct ArtistIndex: Codable {
    let name: String
    let artist: [ArtistInfo]
}

struct AlbumList: Codable {
    let album: [AlbumListResponse]

    var count: Int {
        return album.count
    }

    var isEmpty: Bool {
        return album.isEmpty
    }
}

struct AlbumListResponse: Codable, Identifiable {
    let id: String
    let parent: String?
    let isDir: Bool?
    let title: String?
    let name: String
    let album: String?
    let artist: String
    let year: Int?
    let genre: String?
    let coverArt: String?
    let duration: Int?
    let created: String?
    let artistId: String?
    let songCount: Int?
    let isVideo: Bool?
    let bpm: Int?
    let comment: String?
    let sortName: String?
    let mediaType: String?
    let musicBrainzId: String?
    let isrc: [String]?
    let genres: [Genre]?
    let replayGain: ReplayGain?
    let channelCount: Int?
    let samplingRate: Int?
    let bitDepth: Int?
    let moods: [String]?
    let artists: [ArtistInfo]?
    let displayArtist: String?
    let albumArtists: [ArtistInfo]?
    let displayAlbumArtist: String?
    let contributors: [String]?
    let displayComposer: String?
    let explicitStatus: String?

    var createdDate: Date? {
        guard let created = created else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime, .withFractionalSeconds,
        ]
        return formatter.date(from: created)
    }

    var formattedDuration: String {
        guard let duration = duration else { return "0:00" }
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct Genre: Codable {
    let name: String
}

struct GenresResponse: Codable {
    let genre: [Genre]
}

struct SongsResponse: Codable {
    let song: [SongResponse]
}

struct SongResponse: Codable, Identifiable {
    let id: String
    let parent: String?
    let title: String
    let album: String?
    let artist: String
    let isDir: Bool
    let coverArt: String?
    let created: String?
    let duration: Int?
    let bitRate: Int?
    let track: Int?
    let year: Int?
    let genre: String?
    let size: Int?
    let suffix: String?
    let contentType: String?
    let isVideo: Bool?
    let path: String?
    let albumId: String?
    let artistId: String?
    let type: String?
    let discNumber: Int?
}

struct SearchResult3: Codable {
    let song: [SongResponse]

    init(song: [SongResponse] = []) {
        self.song = song
    }
}

struct ReplayGain: Codable {
}

struct ArtistInfo: Codable, Identifiable {
    let id: String
    let name: String
}

struct ScanStatus: Codable {
    let scanning: Bool
    let count: Int
    let folderCount: Int
    let lastScan: String
    let scanType: String
    let elapsedTime: Int
}

