//
//  Albums.swift
//  drone
//
//  Created by Anthony on 9/4/25.
//

import Foundation
import SwiftUI
import SwiftData

struct AlbumsView: View {
    @EnvironmentObject var server: Server
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Album.name) private var albums: [Album]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Albums")
                        .font(.system(size: 28, weight: .bold))
                    Spacer()
                    Button(action: {
                        Task {
                            await server.sync(modelContext: modelContext)
                        }
                    }) {
                        if server.getIsloading() {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .buttonStyle(.plain)
//                    .foregroundStyle(.)
                }
                .padding(.horizontal, design.View.horizontalPadding)
                .padding(.top, 20)

                if server.isLoading {
                    Text("loading...")
                } else {
                    LazyVGrid(
                        columns: columns,
                        spacing: design.Grid.verticalSpacing
                    ) {
                        albumViewBuilder()
                    }
                    .padding(.horizontal, design.View.horizontalPadding)
                }
            }
            .padding(.bottom, 40)
        }
    }

    private var columns: [GridItem] {
        [
            GridItem(
                .adaptive(minimum: design.Grid.width),
                spacing: design.Grid.horizontalSpacing, alignment: .topLeading)
        ]
    }

    @ViewBuilder
    private func albumViewBuilder() -> some View {
        if albums.isEmpty {
            VStack {
                Spacer()
                Text("No albums available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                if server.getIsloading() {
                    Text("Syncing library...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .frame(height: 300)
        } else {
            ForEach(albums) { album in
                AlbumCard(
                    name: album.name,
                    artist: album.artist,
                    coverArtID: album.coverArt
                )
            }
        }
    }
}

struct AlbumCard: View {
    var name: String
    var artist: String
    var coverArtID: String
    @EnvironmentObject var server: Server
    @State private var image: NSImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    RoundedRectangle(cornerRadius: design.AlbumCard.cornerRadius)
                        .fill(Color.secondary.opacity(0.1))
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary.opacity(0.3))
                        )
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .cornerRadius(design.AlbumCard.cornerRadius)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            .task {
                guard !coverArtID.isEmpty else { return }
                let id = coverArtID
                let data = try? await server.getCoverArt(id: id)
                guard let data else { return }
                image = try? await ImageCacheManager.shared.image(for: id, data: data)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(design.AlbumCard.titleFont)
                    .lineLimit(design.AlbumCard.titleLineLimit)
                    .foregroundStyle(.primary)
                Text(artist)
                    .font(design.AlbumCard.artistFont)
                    .foregroundColor(design.AlbumCard.artistColor)
                    .lineLimit(design.AlbumCard.artistLineLimit)
            }
        }
    }
}

private typealias design = Design.Detail
