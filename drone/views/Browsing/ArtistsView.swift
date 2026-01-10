//
//  ArtistsView.swift
//  drone
//
//  Created by Anthony on 9/4/25.
//

import Foundation
import SwiftUI
import SwiftData

struct ArtistsView: View {
    @Query(sort: \Artist.name) private var artists: [Artist]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Artists")
                    .font(.system(size: 28, weight: .bold))
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                
                if artists.isEmpty {
                    Spacer()
                    Text("No artists available")
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                } else {
                    ForEach(artists) { artist in
                        HStack {
                            Text(artist.name)
                                .font(.headline)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        Divider()
                            .padding(.leading, 20)
                    }
                }
            }
        }
    }
}
