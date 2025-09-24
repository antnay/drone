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
    var duration: Float
    var artistId: String
    var artistImageUrl: String
    var musicBrainzId: String
    var sortName: String
    var displayAlbumArtist: String

    init(
        id: String, albumId: String, parent: String, isDir: Bool, title: String,
        name: String, album: String, artist: String, year: Int, genre: String,
        coverArt: String, duration: Float, artistId: String,
        artistImageUrl: String, musicBrainzId: String, sortName: String,
        displayAlbumArtist: String
    ) {
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
        case albumId
        case parent
        case isDir
        case title
        case name
        case album
        case artist
        case year
        case genre
        case coverArt
        case duration
        case artistId
        case artistImageUrl
        case musicBrainzId
        case sortName
        case displayAlbumArtist
    }

    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)

        self.id =
            try values.decodeIfPresent(String.self, forKey: .id)
            ?? UUID().uuidString
        self.albumId = try values.decode(String.self, forKey: .albumId)
        self.parent = try values.decode(String.self, forKey: .parent)
        self.isDir = try values.decode(Bool.self, forKey: .isDir)
        self.title = try values.decode(String.self, forKey: .title)
        self.name = try values.decode(String.self, forKey: .name)
        self.album = try values.decode(String.self, forKey: .album)
        self.artist = try values.decode(String.self, forKey: .artist)
        self.year = try values.decode(Int.self, forKey: .year)
        self.genre = try values.decode(String.self, forKey: .genre)
        self.coverArt = try values.decode(String.self, forKey: .coverArt)
        self.duration = try values.decode(Float.self, forKey: .duration)
        self.artistId = try values.decode(String.self, forKey: .artistId)
        self.artistImageUrl = try values.decode(
            String.self, forKey: .artistImageUrl)
        self.musicBrainzId = try values.decode(
            String.self, forKey: .musicBrainzId)
        self.sortName = try values.decode(String.self, forKey: .sortName)
        self.displayAlbumArtist = try values.decode(
            String.self, forKey: .displayAlbumArtist)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(albumId, forKey: .albumId)
        try container.encode(parent, forKey: .parent)
        try container.encode(isDir, forKey: .isDir)
        try container.encode(title, forKey: .title)
        try container.encode(name, forKey: .name)
        try container.encode(album, forKey: .album)
        try container.encode(artist, forKey: .artist)
        try container.encode(year, forKey: .year)
        try container.encode(genre, forKey: .genre)
        try container.encode(coverArt, forKey: .coverArt)
        try container.encode(duration, forKey: .duration)
        try container.encode(artistImageUrl, forKey: .artistImageUrl)
        try container.encode(musicBrainzId, forKey: .musicBrainzId)
        try container.encode(sortName, forKey: .sortName)
        try container.encode(displayAlbumArtist, forKey: .displayAlbumArtist)
    }
}
