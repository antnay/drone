//
//  RecentlyAdded.swift
//  drone
//
//  Created by Anthony on 9/4/25.
//

import Foundation
import SwiftUI

struct RecentlyAddedView: View {
    var body: some View {
        AlbumGridView(
            title: "Recently Added",
            sort: [SortDescriptor(\.created, order: .reverse)]
        )
    }
}

