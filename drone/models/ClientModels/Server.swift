//
//  Server.swift
//  drone
//
//  Created by Anthony on 9/4/25.
//

import CryptoKit
import Foundation
import SwiftData
import os

@Model
final class Server: ObservableObject {
    var baseURL: String
    var name: String
    var username: String
    var password: String
    var provider: String
    var status: String
    var lastScan: TimeInterval

    @Attribute(.ephemeral) var isLoading: Bool = false

    static let logger = Logger()
    private final var version = "1.16.1"
    private final var client = "Drone"
    private final var format = "json"

    init() {
        self.baseURL = ""
        self.name = ""
        self.username = ""
        self.password = ""
        self.provider = ""
        self.status = ""
        self.lastScan = 0
    }

    init(url: String, username: String, password: String, name: String) {
        self.baseURL = Server.validateURL(url: url)
        self.username = username
        self.password = password
        self.name = name
        self.provider = ""
        self.status = ""
        self.lastScan = 0
    }

    func getIsloading() -> Bool {
        return self.isLoading
    }

    private static func validateURL(url: String) -> String {
        if url.isEmpty { return "" }
        if url.starts(with: /https?:\/\//) {
            return url
        }
        if url.contains(":") {
            return "http://" + url
        }
        return "https://" + url
    }

    private func salter() -> String {
        let letters =
            "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<15).map { _ in letters.randomElement()! })
    }

    private func md5(from string: String) -> String {
        let data = Data(string.utf8)
        let hash = Insecure.MD5.hash(data: data)
            .withUnsafeBytes { Data($0) }
            .hexEncodedString

        return hash
    }

    func updateConnection(
        url: String,
        username: String,
        password: String,
        name: String
    ) {
        self.baseURL = Server.validateURL(url: url)
        self.username = username
        self.password = password
        self.name = name
    }

    // Generic API call helper
    private func apiCall<T: Codable>(
        endpoint: String,
        params: [URLQueryItem] = []
    ) async throws -> T? {
        let salt = salter()
        let token = md5(from: "\(password)\(salt)")

        var components = URLComponents(string: baseURL)
        components?.path = "/rest/\(endpoint)"

        var queryItems = [
            URLQueryItem(name: "u", value: username),
            URLQueryItem(name: "t", value: token),
            URLQueryItem(name: "s", value: salt),
            URLQueryItem(name: "v", value: version),
            URLQueryItem(name: "c", value: client),
            URLQueryItem(name: "f", value: format),
        ]
        queryItems.append(contentsOf: params)
        components?.queryItems = queryItems

        guard let finalURL = components?.url else {
            throw URLError(.badURL)
        }

        Server.logger.debug("Requesting: \(finalURL.absoluteString)")

        let (data, _) = try await URLSession.shared.data(from: finalURL)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TopLevel<T>.self, from: data)

        if let error = decoded.subsonicResponse.error {
            Server.logger.debug(
                "subsonic api error: { code: \(error.code), message: \(error.message) }"
            )
            throw SubsonicAPIError.serverError(
                code: error.code,
                message: error.message
            )
        }

        return decoded.subsonicResponse.data
    }

    func streamURL(for songID: String) -> URL? {
        let salt = salter()
        let token = md5(from: "\(password)\(salt)")
        var components = URLComponents(string: baseURL)
        components?.path = "/rest/stream"
        components?.queryItems = [
            URLQueryItem(name: "id", value: songID),
            URLQueryItem(name: "u", value: username),
            URLQueryItem(name: "t", value: token),
            URLQueryItem(name: "s", value: salt),
            URLQueryItem(name: "v", value: version),
            URLQueryItem(name: "c", value: client),
        ]
        return components?.url
    }
    
    func getCoverArt(id: String, size: Int = 300) async throws -> Data {
        let salt = salter()
        let token = md5(from: "\(password)\(salt)")
        var components = URLComponents(string: baseURL)
        components?.path = "/rest/getCoverArt"
        components?.queryItems = [
            URLQueryItem(name: "id", value: id),
            URLQueryItem(name: "size", value: "\(size)"),
            URLQueryItem(name: "u", value: username),
            URLQueryItem(name: "t", value: token),
            URLQueryItem(name: "s", value: salt),
            URLQueryItem(name: "v", value: version),
            URLQueryItem(name: "c", value: client),
        ]
        guard let url = components?.url else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }

    func ping() async throws -> SubsonicResponse<PingResponse>? {
        let salt = salter()
        let token = md5(from: "\(password)\(salt)")

        var components = URLComponents(string: baseURL)
        components?.path = "/rest/ping"
        components?.queryItems = [
            URLQueryItem(name: "u", value: username),
            URLQueryItem(name: "t", value: token),
            URLQueryItem(name: "s", value: salt),
            URLQueryItem(name: "v", value: version),
            URLQueryItem(name: "c", value: client),
            URLQueryItem(name: "f", value: format),
        ]

        guard let finalURL = components?.url else {
            throw URLError(.badURL)
        }

        let (data, _) = try await URLSession.shared.data(from: finalURL)
        let decoded = try JSONDecoder().decode(
            TopLevel<PingResponse>.self,
            from: data
        )
        return decoded.subsonicResponse
    }

    func getAlbumList(type: String = "newest", size: Int = 50, offset: Int = 0)
        async throws -> AlbumList
    {
        return try await apiCall(
            endpoint: "getAlbumList",
            params: [
                URLQueryItem(name: "type", value: type),
                URLQueryItem(name: "size", value: size.description),
                URLQueryItem(name: "offset", value: offset.description),
            ]
        ) ?? AlbumList(album: [])
    }

    func getArtists() async throws -> ArtistsResponse {
        return try await apiCall(endpoint: "getArtists")
            ?? ArtistsResponse(index: [])
    }

    func getGenres() async throws -> GenresResponse {
        return try await apiCall(endpoint: "getGenres")
            ?? GenresResponse(genre: [])
    }

    // Retrives information from single album
    func getAlbum(albumId: String) async throws -> SongsResponse {
        return try await apiCall(
            endpoint: "getAlbum",
            params: [URLQueryItem(name: "id", value: albumId)]
        ) ?? SongsResponse(song: [])
    }
    

    @MainActor
    func sync(modelContext: ModelContext) async {
        if baseURL.isEmpty { return }
        self.isLoading = true
        defer { self.isLoading = false }

        do {
            try modelContext.delete(model: Album.self)
            try modelContext.delete(model: Artist.self)
            try modelContext.save()

            var offset = 0
            var albumList = try await getAlbumList(size: 200, offset: offset)
            while !albumList.isEmpty {
                for albumData in albumList.album {
                    let album = Album(
                        id: albumData.id,
                        albumId: albumData.id,
                        parent: albumData.parent ?? "",
                        isDir: albumData.isDir ?? true,
                        title: albumData.title ?? albumData.name,
                        name: albumData.name,
                        album: albumData.album ?? albumData.name,
                        artist: albumData.artist,
                        year: albumData.year ?? 0,
                        genre: albumData.genre ?? "",
                        coverArt: albumData.coverArt ?? "",
                        duration: Float(albumData.duration ?? 0),
                        artistId: albumData.artistId ?? "",
                        musicBrainzId: albumData.musicBrainzId ?? "",
                        sortName: albumData.sortName ?? albumData.name,
                        displayAlbumArtist: albumData.displayAlbumArtist
                            ?? albumData.artist,
                        created: albumData.createdDate ?? Date()
                    )
                    modelContext.insert(album)
                }
                try modelContext.save()
                offset += 200
                albumList = try await getAlbumList(size: 200, offset: offset)
            }

            let artistsResponse = try await getArtists()
            for index in artistsResponse.index {
                for artistInfo in index.artist {
                    let artist = Artist(
                        artistID: artistInfo.id,
                        name: artistInfo.name,
                        coverArt: "",
                        albumCount: 0,
                        artistImageUrl: "",
                        musicBrainzId: "",
                        sortName: artistInfo.name
                    )
                    modelContext.insert(artist)
                }
            }

            try modelContext.save()
            Server.logger.info("Sync complete")
        } catch {
            Server.logger.error("Sync failed: \(error.localizedDescription)")
        }
    }
}

enum SubsonicAPIError: Error, LocalizedError {
    case serverError(code: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .serverError(let code, let message):
            return "Subsonic error \(code): \(message)"
        }
    }
}

extension Data {
    var hexEncodedString: String {
        map { String(format: "%02hhx", $0) }.joined()
    }
}
