import SwiftUI

@MainActor
class NavigationRouter: ObservableObject {
    @Published var selectedNavItem: NavigationItem = .albums
    @Published var path = NavigationPath()
    @Published var pendingAlbum: Album? = nil
    @Published var pendingArtist: Artist? = nil

    // Invalidates stale deferred navigations when a newer one supersedes them
    // before they land (e.g. two rapid "go to album" taps).
    private var navigationToken = 0

    func navigate(to item: NavigationItem) {
        navigationToken += 1
        selectedNavItem = item
        path = NavigationPath()
    }

    func navigate(to album: Album) {
        navigationToken += 1
        let token = navigationToken
        path = NavigationPath()
        selectedNavItem = .albums
        pendingAlbum = nil
        Task { @MainActor in
            guard token == self.navigationToken else { return }
            self.pendingAlbum = album
        }
    }

    func navigate(to artist: Artist) {
        navigationToken += 1
        let token = navigationToken
        path = NavigationPath()
        selectedNavItem = .artists
        pendingArtist = nil
        Task { @MainActor in
            guard token == self.navigationToken else { return }
            self.pendingArtist = artist
        }
    }
}
