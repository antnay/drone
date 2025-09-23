//
//  SidebarSelection.swift
//  drone
//
//  Created by Anthony on 9/4/25.
//

import Foundation

enum NavigationItem: String, CaseIterable, Identifiable {
    case recentlyAdded = "Recently Added"
    case artists = "Artists"
    case albums = "Albums"
    case songs = "Songs"
    case playlists = "Playlists"
    case genres = "Genres"

    var id: String { self.rawValue }

    var icon: String {
        switch self {
        case .recentlyAdded: return "clock"
        case .artists: return "music.mic"
        case .albums: return "square.stack"
        case .songs: return "music.note"
        case .playlists: return "music.note.list"
        case .genres: return "guitars"
        }
    }

    var allowsList: Bool {
        self != .albums
    }

    var displayImageName: String {
        switch self {
        case .recentlyAdded: return "clock"
        case .artists: return "music.mic"
        case .albums: return "square.stack"
        case .songs: return "music.note"
        case .playlists: return "music.note.list"
        case .genres: return "guitars"
        }
    }

    var displayName: String {
        switch self {
        case .recentlyAdded: return "Recently Added"
        case .artists: return "Artists"
        case .albums: return "Albums"
        case .songs: return "Songs"
        case .playlists: return "Playlists"
        case .genres: return "Genres"
        }
    }
}
