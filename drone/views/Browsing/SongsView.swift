//
//  SongsView.swift
//  drone
//
//  Created by Anthony on 9/4/25.
//

import Foundation
import SwiftUI
import SwiftData

struct SongsView: View {
    @Query(sort: \Song.title) private var songs: [Song]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Songs")
                    .font(.system(size: 28, weight: .bold))
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                
                if songs.isEmpty {
                    Spacer()
                    Text("No songs available")
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                } else {
                    ForEach(songs) { song in
                        HStack(spacing: 15) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.1))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: "music.note")
                                        .foregroundStyle(.secondary.opacity(0.5))
                                )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(song.title)
                                    .font(.headline)
                                Text(song.artist)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(String(format: "%d:%02d", song.duration / 60, song.duration % 60))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 4)
                        Divider()
                            .padding(.leading, 75)
                    }
                }
            }
        }
    }
}
