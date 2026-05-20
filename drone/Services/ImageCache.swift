//
//  ImageCache.swift
//  drone
//
//  Created by Anthony on 5/19/26.
//

import Foundation
import AppKit

actor ImageCacheManager {
    static let shared = ImageCacheManager()
    
    private let cache = NSCache<NSString, NSImage>()
    private let cacheDir: URL
    private var inFlight: [String: Task<NSImage, Error>] = [:]
    
    init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDir = caches.appendingPathComponent("CoverArt", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }
    
    func image(for coverArtID: String, data: Data) async throws -> NSImage {
        if let cached = cache.object(forKey: coverArtID as NSString) {
            return cached
        }
        
        let fileURL = cacheDir.appendingPathComponent("\(coverArtID).jpg")
        if let diskData = try? Data(contentsOf: fileURL), let img = NSImage(data: diskData) {
            cache.setObject(img, forKey: coverArtID as NSString)
            return img
        }
        
        try data.write(to: fileURL)
        guard let img = NSImage(data: data) else {
            throw URLError(.cannotDecodeContentData)
        }
        cache.setObject(img, forKey: coverArtID as NSString)
        return img
    }
    
    func clearCache() throws {
        cache.removeAllObjects()
        let files = try FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil)
        for file in files {
            try FileManager.default.removeItem(at: file)
        }
    }
}
