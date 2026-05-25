//
//  ContentView.swift
//  drone
//
//  Created by Anthony on 9/4/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var server: Server
    @EnvironmentObject var player: APlayer
    @EnvironmentObject var router: NavigationRouter
    @State private var searchText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            NavigationSplitView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Library")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 8)

                    List(NavigationItem.allCases, selection: $router.selectedNavItem) { item in
                        NavigationLink(value: item) {
                            Label(item.rawValue, systemImage: item.icon)
                                .font(.system(size: 13, weight: .medium))
                        }
                    }
                    .listStyle(.sidebar)
                }
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 250)

                if server.getIsloading() {
                    Spacer()
                    HStack {
                        ProgressView()
                            .scaleEffect(0.5)
                        Text("Loading library...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 20)
                }
            } detail: {
                NavigationStack(path: $router.path) {
                    DetailView(sidebarSelection: $router.selectedNavItem)
                        .onChange(of: router.pendingAlbum) { _, album in
                            if let album {
                                router.path.append(album)
                                router.pendingAlbum = nil
                            }
                        }
                        .onChange(of: router.pendingArtist) { _, artist in
                            if let artist {
                                router.path.append(artist)
                                router.pendingArtist = nil
                            }
                        }
                        .navigationDestination(for: Album.self) { album in
                            AlbumDetailView(album: album)
                        }
                        .navigationDestination(for: Artist.self) { artist in
                            ArtistDetailView(artist: artist)
                        }
                        .toolbar {
                            ToolbarItem(placement: .navigation) {
                                Button(action: {}) {
                                    Image(systemName: "chevron.left")
                                }
                            }
                            ToolbarItem(placement: .navigation) {
                                Button(action: {}) {
                                    Image(systemName: "chevron.right")
                                }
                            }
                            ToolbarItem(placement: .primaryAction) {
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundStyle(.secondary)
                                    TextField("Search", text: $searchText)
                                        .textFieldStyle(.plain)
                                        .frame(width: 150)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                }
            }

            PlayerView()
        }
    }
}
