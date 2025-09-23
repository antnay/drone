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
    let artist: [Artist]
}

struct GenresResponse: Codable {
    let index: [Genre]
}

struct Genre: Codable {
    let value: String
    let songCount: Int
    let albumCount: Int
}

struct ScanStatus: Codable {
    let scanning: Bool
    let count: Int
    let folderCount: Int
    let lastScan: String
    let scanType: String
    let elapsedTime: Int
}
