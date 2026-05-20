//
//  Albums.swift
//  drone
//
//  Created by Anthony on 9/4/25.
//

import Foundation
import SwiftData
import SwiftUI

struct AlbumGridView: View {
    @EnvironmentObject var server: Server
    @Environment(\.modelContext) private var modelContext
    @Query private var albums: [Album]

    let title: String

    init(
        title: String,
        sort: [SortDescriptor<Album>],
        predicate: Predicate<Album>? = nil,
        limit: Int? = nil
    ) {
        self.title = title
        var descriptor = FetchDescriptor<Album>(
            predicate: predicate,
            sortBy: sort
        )
        descriptor.fetchLimit = limit
        _albums = Query(descriptor)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text(title)
                        .font(.system(size: 28, weight: .bold))
                    Spacer()
                    Button(action: {
                        Task { await server.sync(modelContext: modelContext) }
                    }) {
                        if server.getIsloading() {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, design.View.horizontalPadding)
                .padding(.top, 20)

                LazyVGrid(
                    columns: columns,
                    spacing: design.Grid.verticalSpacing
                ) {
                    albumViewBuilder()
                }
                .padding(.horizontal, design.View.horizontalPadding)
            }
            .padding(.bottom, 40)
        }
    }

    private var columns: [GridItem] {
        [
            GridItem(
                .adaptive(minimum: design.Grid.width),
                spacing: design.Grid.horizontalSpacing,
                alignment: .topLeading
            )
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
                    album: album
                )
            }
        }
    }
}

struct AlbumCard: View {
    let album: Album
    @EnvironmentObject var server: Server
    @State private var image: NSImage?

    var body: some View {
        NavigationLink(destination: AlbumDetailView(album: album)) {
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
                    guard !album.coverArt.isEmpty else { return }
                    let id = album.coverArt
                    let data = try? await server.getCoverArt(id: id)
                    guard let data else { return }
                    image = try? await ImageCacheManager.shared.image(for: id, data: data)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(album.name)
                        .font(design.AlbumCard.titleFont)
                        .lineLimit(design.AlbumCard.titleLineLimit)
                        .foregroundStyle(.primary)
                    Text(album.artist)
                        .font(design.AlbumCard.artistFont)
                        .foregroundColor(design.AlbumCard.artistColor)
                        .lineLimit(design.AlbumCard.artistLineLimit)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private typealias design = Design.Detail
