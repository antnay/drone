//
//  Artist.swift
//  drone
//
//  Created by Anthony on 9/4/25.
//

import Foundation
import SwiftData

//@Model
//struct Artist: Identifiable, Codable {
////    @Attribute(.unique) var id: String
//    var artistID: String
//    var name: String
//    var coverArt: String
//    var albumCount: Int
//    var artistImageUrl: String
//    var musicBrainzId: String
//    var sortName: String
//    var roles: [String]
//
//    init(
//        artistID: String, name: String, coverArt: String, albumCount: Int,
//        artistImageUrl: String, musicBrainzId: String, sortName: String,
//        roles: [String]
//    ) {
//        self.artistID = artistID
//        self.name = name
//        self.coverArt = coverArt
//        self.albumCount = albumCount
//        self.artistImageUrl = artistImageUrl
//        self.musicBrainzId = musicBrainzId
//        self.sortName = sortName
//        self.roles = roles
//    }
//
//    init(from decoder: Decoder) throws {
//        let container = try decoder.container(keyedBy: CodingKeys.self)
//
//        //            self.id =
//        //                try container.decodeIfPresent(String.self, forKey: .id)
//        //                ?? UUID().uuidString
//        self.artistID = try container.decode(String.self, forKey: .artistID)
//        self.name = try container.decode(String.self, forKey: .name)
//        self.coverArt = try container.decode(String.self, forKey: .coverArt)
//        self.albumCount = try container.decode(Int.self, forKey: .albumCount)
//        self.artistImageUrl = try container.decode(
//            String.self, forKey: .artistImageUrl)
//        self.musicBrainzId = try container.decode(
//            String.self, forKey: .musicBrainzId)
//        self.sortName = try container.decode(String.self, forKey: .sortName)
//        self.roles = try container.decode([String].self, forKey: .roles)
//    }
//
//    enum CodingKeys: String, CodingKey {
//        case id
//        case artistID
//        case name
//        case coverArt
//        case albumCount
//        case artistImageUrl
//        case musicBrainzId
//        case sortName
//        case roles
//    }
//
//    func encode(to encoder: Encoder) throws {
//        var container = encoder.container(keyedBy: CodingKeys.self)
//        //            try container.encode(id, forKey: .id)
//        try container.encode(artistID, forKey: .artistID)
//        try container.encode(name, forKey: .name)
//        try container.encode(coverArt, forKey: .coverArt)
//        try container.encode(albumCount, forKey: .albumCount)
//        try container.encode(artistImageUrl, forKey: .artistImageUrl)
//        try container.encode(musicBrainzId, forKey: .musicBrainzId)
//        try container.encode(sortName, forKey: .sortName)
//        try container.encode(roles, forKey: .roles)
//    }
//}

@Model
final class Album: Identifiable, Codable {
    @Attribute(.unique) var id: String
    var albumId: String
    var parent: String
    var isDir: Bool
    var title: String
    var name: String
    var album: String
    var artist: String
    var year: Int
    var genre: String
    var coverArt: String
    var duration: Int
    var artistId: String
    var artistImageUrl: String
    var musicBrainzId: String
    var sortName: String
    var displayAlbumArtist: String

    init(id: String, albumId: String, parent: String, isDir: Bool, title: String, name: String, album: String, artist: String, year: Int, genre: String, coverArt: String, duration: Int, artistId: String, artistImageUrl: String, musicBrainzId: String, sortName: String, displayAlbumArtist: String) {
        self.id = id
        self.albumId = albumId
        self.parent = parent
        self.isDir = isDir
        self.title = title
        self.name = name
        self.album = album
        self.artist = artist
        self.year = year
        self.genre = genre
        self.coverArt = coverArt
        self.duration = duration
        self.artistId = artistId
        self.artistImageUrl = artistImageUrl
        self.musicBrainzId = musicBrainzId
        self.sortName = sortName
        self.displayAlbumArtist = displayAlbumArtist
    }

    enum CodingKeys: String, CodingKey {
        case id
//        var albumId: String
//        var parent: String
//        var isDir: Bool
//        var title: String
//        var name: String
//        var album: String
//        var artist: String
//        var year: Int
//        var genre: String
//        var coverArt: String
//        var duration: Int
//        var artistId: String
//        var artistImageUrl: String
//        var musicBrainzId: String
//        var sortName: String
//        var displayAlbumArtist: String
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id =
            try container.decodeIfPresent(String.self, forKey: .id)
            ?? UUID().uuidString
        self.albumId = try container.decode(String.self, forKey: .albumId)
        self.artistID = try container.decode(String.self, forKey: .artistID)
        self.name = try container.decode(String.self, forKey: .name)
        self.coverArt = try container.decode(String.self, forKey: .coverArt)
        self.albumCount = try container.decode(Int.self, forKey: .albumCount)
        self.artistImageUrl = try container.decode(
            String.self, forKey: .artistImageUrl)
        self.musicBrainzId = try container.decode(
            String.self, forKey: .musicBrainzId)
        self.sortName = try container.decode(String.self, forKey: .sortName)
        self.roles = try container.decode([String].self, forKey: .roles)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(albumId, forKey:
        try container.encode(artistID, forKey: .artistID)
        try container.encode(name, forKey: .name)
        try container.encode(coverArt, forKey: .coverArt)
        try container.encode(albumCount, forKey: .albumCount)
        try container.encode(artistImageUrl, forKey: .artistImageUrl)
        try container.encode(musicBrainzId, forKey: .musicBrainzId)
        try container.encode(sortName, forKey: .sortName)
        try container.encode(roles, forKey: .roles)
    }
}
