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
    @Environment(\.openWindow) private var openWindow
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
            NavigationSplitView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Library")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 8)

                    // Selection-driven sidebar: the List's selection binding is
                    // the single source of truth for which section is shown
                    // (DetailView switches on router.selectedNavItem). Do NOT
                    // also wrap rows in NavigationLink — a selectable List plus
                    // NavigationLink pushes the selection write and the link
                    // activation into the same update pass, which is the source
                    // of the "Publishing changes from within view updates"
                    // warning when switching sections.
                    List(
                        NavigationItem.allCases,
                        selection: $router.selectedNavItem
                    ) { item in
                        Label(item.rawValue, systemImage: item.icon)
                            .font(.system(size: 13, weight: .medium))
                            .tag(item)
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
                    Group {
                        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            DetailView(sidebarSelection: $router.selectedNavItem)
                        } else {
                            SearchResultsView(searchText: $searchText)
                        }
                    }
                        .onChange(of: router.pendingAlbum) { _, album in
                            if let album {
                                searchText = ""
                                router.path.append(album)
                                router.pendingAlbum = nil
                            }
                        }
                        .onChange(of: router.pendingArtist) { _, artist in
                            if let artist {
                                searchText = ""
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
                                        .focused($isSearchFocused)
                                        .frame(width: 150)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(8)
                                .contentShape(Rectangle())
                                .onTapGesture { isSearchFocused = true }
                            }
                        }
                }
            }

            if player.showQueueSidebar {
                Divider()
                QueueSidebar()
                    .environmentObject(server)
                    .environmentObject(player)
                    .transition(.move(edge: .trailing))
            }
            }

            PlayerView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .droneReopenRequested)) { _ in
            openWindow(id: "main")
        }
    }
}
