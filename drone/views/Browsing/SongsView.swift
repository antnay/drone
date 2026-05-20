//
//  SongsView.swift
//  drone
//
//  Created by Anthony on 9/4/25.
//

import Foundation
import SwiftData
import SwiftUI

struct SongsView: View {
    @EnvironmentObject var server: Server
    @State private var songs: [Song] = []
    @State private var isLoading = false
    @State private var offset = 0
    @State private var hasMore = true
    private let pageSize = 50

    var body: some View {
//        ScrollView {
//            VStack(alignment: .leading, spacing: 20) {
//                Text("Songs")
//                    .font(.system(size: 28, weight: .bold))
//                    .padding(.horizontal, 20)
//                    .padding(.top, 20)
//
//                LazyVStack(spacing: 0) {
//                    ForEach(songs) { song in
//                        SongRow(song: song)
//                            .onAppear {
//                                if song.id == songs.last?.id {
//                                    loadMore()
//                                }
//                            }
//                    }
//                }
//            }
//        }
//        .task { loadMore() }
    }

//    private func loadMore() {
//        guard !isLoading, hasMore else { return }
//        isLoading = true
//        Task {
//            do {
//                let results = try await server.search3(
//                    query: "",
//                    songCount: pageSize,
//                    songOffset: offset
//                )
//                let newSongs = results.song.map { /* map to Song */  }
//                songs.append(contentsOf: newSongs)
//                hasMore = newSongs.count == pageSize
//                offset += pageSize
//            } catch {
//                Server.logger.error(
//                    "Failed to load songs: \(error.localizedDescription)"
//                )
//            }
//            isLoading = false
//        }
//    }
}
