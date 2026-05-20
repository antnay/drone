//
//  Albums.swift
//  drone
//
//  Created by Anthony on 9/4/25.
//

import Foundation
import SwiftData
import SwiftUI

struct AlbumsView: View {

    var body: some View {
        AlbumGridView(
            title: "Albums",
            sort: [SortDescriptor(\.name)]
        )
    }
}
