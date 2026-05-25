import SwiftUI

@MainActor
class NavigationRouter: ObservableObject {
    @Published var selectedNavItem: NavigationItem = .albums
    @Published var path = NavigationPath()
    @Published var pendingAlbum: Album? = nil
    @Published var pendingArtist: Artist? = nil

    func navigate(to item: NavigationItem) {
        selectedNavItem = item
        path = NavigationPath()
    }

    func navigate(to album: Album) {
        path = NavigationPath()
        selectedNavItem = .albums
        pendingAlbum = album
    }

    func navigate(to artist: Artist) {
        path = NavigationPath()
        selectedNavItem = .artists
        pendingArtist = artist
    }
}
