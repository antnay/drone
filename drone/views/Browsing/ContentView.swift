//
//  ContentView.swift
//  drone
//
//  Created by Anthony on 9/4/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var server: Server
    @State private var selectedNavItem: NavigationItem = .albums
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
                    
                    List(NavigationItem.allCases, selection: $selectedNavItem) { item in
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
                NavigationStack {
                    DetailView(sidebarSelection: $selectedNavItem)
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
