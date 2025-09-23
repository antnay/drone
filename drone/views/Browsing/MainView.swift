//
//  MainView.swift
//  drone
//
//  Created by Anthony on 9/4/25.
//

import Foundation
import SwiftUI

struct DetailView: View {
    @Binding var sidebarSelection: NavigationItem
    var body: some View {
        Group {
            switch sidebarSelection {
            case .albums:
                AlbumsView()
            case .artists:
                ArtistsView()
            case .songs:
                SongsView()
            case .playlists:
                PlaylistsView()
            case .genres:
                GenresView()
            case .recentlyAdded:
                RecentlyAddedView()
            }
        }
    }
}
