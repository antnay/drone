//
//  Server.swift
//  drone
//
//  Created by Anthony on 9/4/25.
//

import CryptoKit
import Foundation
import SwiftData

@Model
final class Credentials {
    var username: String
    var password: String

    init(username: String, password: String) {
        self.username = username
        self.password = password
    }

    enum KeychainError: Error {
        case noPassword
        case unexpectedPasswordData
        case unhandledError(status: OSStatus)
    }
}

@Model
final class Server {
    var url: String
    var credentials: Credentials?
    var name: String
    var provider: String?
    var status: String?
    var lastScan: TimeInterval?

    init() {
        self.url = ""
        self.name = ""
    }

    init(url: String, credentials: Credentials, name: String) {
        self.url = Server.validateURL(url: url)
        self.credentials = credentials
        self.name = name
    }

    init(
        url: String, credentials: Credentials, name: String,
        provider: String? = nil, status: String? = nil,
        lastScan: TimeInterval? = nil
    ) {
        self.url = Server.validateURL(url: url)
        self.credentials = credentials
        self.name = name
        self.provider = provider
        self.status = status
        self.lastScan = lastScan
    }

    private static func validateURL(url: String) -> String {
        if url.starts(with: /https?:\/\//) {  // does not contain http or https
            print("case 1")
            return url
        }
        if url.contains(/:{0-9}{1,6}/) {  // has :port
            print("case 3")
            return "http://" + url
        }
        if url.contains(/.{a-z}{1,5}/) {  // has .something
            print("case 3")
            return "https://" + url
        }
        return url
    }

    private func salter() -> String {
        return SymmetricKey(size: .bits192).withUnsafeBytes { Data($0) }
            .base64EncodedString()
    }

    private func md5(from string: String) -> String {
        let data = Data(string.utf8)
        let hash = Insecure.MD5.hash(data: data)
            .withUnsafeBytes { Data($0) }
            .hexEncodedString

        return hash
    }

    func setUrl(url: String) {
        self.url = Server.validateURL(url: url)
    }

    func ping() async throws -> SubsonicResponse<PingResponse>? {
        let salt = salter()
        let token = md5(from: "\(credentials?.password ?? "")\(salt)")
        print(salt)
        print()
        print(token)
        print(self.url)
        print(self.credentials?.username as Any)
        print(self.credentials?.password as Any)

        var components = URLComponents(string: url)
        components?.path = "/rest/ping"
        components?.queryItems = [
            URLQueryItem(name: "u", value: credentials?.username ?? ""),
            URLQueryItem(name: "t", value: token),
            URLQueryItem(name: "s", value: salt),
            URLQueryItem(name: "v", value: "1.16.1"),
            URLQueryItem(name: "c", value: "Drone"),
            URLQueryItem(name: "f", value: "json"),
        ]

        guard let finalURL = components?.url else {
            throw URLError(.badURL)
        }

        print("url", finalURL)

        let (data, _) = try await URLSession.shared.data(from: finalURL)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(
            TopLevel<PingResponse>.self, from: data)
        return decoded.subsonicResponse
    }
    
    func search(query: String) {}
    func getAlbum(id: String) {}
    func getAlbumList() {}
}

extension Data {
    var hexEncodedString: String {
        map { String(format: "%02hhx", $0) }.joined()
    }
}
