//
//  Song.swift
//  drone
//
//  Created by Anthony on 1/10/26.
//

import Foundation
import SwiftData

@Model
final class Song: Identifiable, Codable {
    @Attribute(.unique) var id: String
    var songID: String
    var parent: String
    var title: String
    var album: String
    var artist: String
    var isDir: Bool
    var coverArt: String
    var created: String
    var duration: Int
    var bitRate: Int
    var track: Int
    var year: Int
    var genre: String
    var size: Int
    var suffix: String
    var contentType: String
    var isVideo: Bool
    var path: String
    var albumId: String
    var artistId: String
    var type: String
    var discNumber: Int

    init(
        songID: String, parent: String, title: String, album: String,
        artist: String, isDir: Bool, coverArt: String, created: String,
        duration: Int, bitRate: Int, track: Int, year: Int, genre: String,
        size: Int, suffix: String, contentType: String, isVideo: Bool,
        path: String, albumId: String, artistId: String, type: String,
        discNumber: Int
    ) {
        self.id = UUID().uuidString
        self.songID = songID
        self.parent = parent
        self.title = title
        self.album = album
        self.artist = artist
        self.isDir = isDir
        self.coverArt = coverArt
        self.created = created
        self.duration = duration
        self.bitRate = bitRate
        self.track = track
        self.year = year
        self.genre = genre
        self.size = size
        self.suffix = suffix
        self.contentType = contentType
        self.isVideo = isVideo
        self.path = path
        self.albumId = albumId
        self.artistId = artistId
        self.type = type
        self.discNumber = discNumber
    }

    enum CodingKeys: String, CodingKey {
        case id
        case songID
        case parent
        case title
        case album
        case artist
        case isDir
        case coverArt
        case created
        case duration
        case bitRate
        case track
        case year
        case genre
        case size
        case suffix
        case contentType
        case isVideo
        case path
        case albumId
        case artistId
        case type
        case discNumber
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.songID = try container.decodeIfPresent(String.self, forKey: .songID) ?? ""
        self.parent = try container.decodeIfPresent(String.self, forKey: .parent) ?? ""
        self.title = try container.decode(String.self, forKey: .title)
        self.album = try container.decodeIfPresent(String.self, forKey: .album) ?? ""
        self.artist = try container.decode(String.self, forKey: .artist)
        self.isDir = try container.decode(Bool.self, forKey: .isDir)
        self.coverArt = try container.decodeIfPresent(String.self, forKey: .coverArt) ?? ""
        self.created = try container.decodeIfPresent(String.self, forKey: .created) ?? ""
        self.duration = try container.decodeIfPresent(Int.self, forKey: .duration) ?? 0
        self.bitRate = try container.decodeIfPresent(Int.self, forKey: .bitRate) ?? 0
        self.track = try container.decodeIfPresent(Int.self, forKey: .track) ?? 0
        self.year = try container.decodeIfPresent(Int.self, forKey: .year) ?? 0
        self.genre = try container.decodeIfPresent(String.self, forKey: .genre) ?? ""
        self.size = try container.decodeIfPresent(Int.self, forKey: .size) ?? 0
        self.suffix = try container.decodeIfPresent(String.self, forKey: .suffix) ?? ""
        self.contentType = try container.decodeIfPresent(String.self, forKey: .contentType) ?? ""
        self.isVideo = try container.decodeIfPresent(Bool.self, forKey: .isVideo) ?? false
        self.path = try container.decodeIfPresent(String.self, forKey: .path) ?? ""
        self.albumId = try container.decodeIfPresent(String.self, forKey: .albumId) ?? ""
        self.artistId = try container.decodeIfPresent(String.self, forKey: .artistId) ?? ""
        self.type = try container.decodeIfPresent(String.self, forKey: .type) ?? ""
        self.discNumber = try container.decodeIfPresent(Int.self, forKey: .discNumber) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(songID, forKey: .songID)
        try container.encode(parent, forKey: .parent)
        try container.encode(title, forKey: .title)
        try container.encode(album, forKey: .album)
        try container.encode(artist, forKey: .artist)
        try container.encode(isDir, forKey: .isDir)
        try container.encode(coverArt, forKey: .coverArt)
        try container.encode(created, forKey: .created)
        try container.encode(duration, forKey: .duration)
        try container.encode(bitRate, forKey: .bitRate)
        try container.encode(track, forKey: .track)
        try container.encode(year, forKey: .year)
        try container.encode(genre, forKey: .genre)
        try container.encode(size, forKey: .size)
        try container.encode(suffix, forKey: .suffix)
        try container.encode(contentType, forKey: .contentType)
        try container.encode(isVideo, forKey: .isVideo)
        try container.encode(path, forKey: .path)
        try container.encode(albumId, forKey: .albumId)
        try container.encode(artistId, forKey: .artistId)
        try container.encode(type, forKey: .type)
        try container.encode(discNumber, forKey: .discNumber)
    }
}
