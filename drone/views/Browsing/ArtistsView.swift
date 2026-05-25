//
//  ArtistsView.swift
//  drone
//
//  Created by Anthony on 9/4/25.
//

import Foundation
import SwiftData
import SwiftUI

struct ArtistsView: View {
    @Query(sort: \Artist.name) private var artists: [Artist]
    @State private var hoveredID: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Artists")
                    .font(.system(size: 28, weight: .bold))
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 16)

                if artists.isEmpty {
                    Text("No artists available")
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 24)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(artists) { artist in
                            artistRow(artist)
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
    }

    private func artistRow(_ artist: Artist) -> some View {
        let isHovered = hoveredID == artist.id
        return NavigationLink(value: artist) {
            HStack {
                Text(artist.name)
                    .font(.system(size: 14))
                    .foregroundStyle(isHovered ? Color.accentColor : .primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isHovered ? Color.primary.opacity(0.04) : .clear)
        .overlay(alignment: .bottom) { Divider().opacity(0.15) }
        .onHover { hoveredID = $0 ? artist.id : nil }
    }
}
