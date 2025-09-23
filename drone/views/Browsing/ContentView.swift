//
//  ContentView.swift
//  drone
//
//  Created by Anthony on 9/4/25.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedNavItem: NavigationItem = .albums
    @State private var searchText: String = ""

    var body: some View {
        NavigationSplitView {
            Text("Library")
                .clipped()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 15)
                .padding(.top, 10)
                .foregroundStyle(.secondary)
                .font(.system(size: 12))
                .fontWeight(.medium)
            List(NavigationItem.allCases, selection: $selectedNavItem) { item in
                NavigationLink(value: item) {
                    Label(item.rawValue, systemImage: item.icon)
                }
            }
            .padding([.leading], 5)
            Spacer()
            //            if musicLibrary.isLoading {
            //                HStack {
            //                    ProgressView()
            //                        .scaleEffect(0.4)
            //                    Text("Loading library")
            //                        .font(.subheadline)
            //                        .foregroundStyle(.secondary)
            //
            //                }
            //                .padding(.bottom, 5)
            //            }
        } detail: {
            NavigationStack {
                ScrollView {
                    DetailView(sidebarSelection: $selectedNavItem)
                        .padding(.all, 5)
                }
            }
        }
        .toolbar {
            ToolbarItem {
                Button(
                    "Play", systemImage: "play.fill",
                    action: { print("pressed play") })
            }
        }

    }

}
