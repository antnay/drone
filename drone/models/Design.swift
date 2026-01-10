//
//  Design.swift
//  drone
//
//  Created by Anthony on 9/24/25.
//

import Foundation
import SwiftUI
import WidgetKit

enum Design {
    enum Detail {
        enum View {
            static var horizontalPadding: CGFloat { 20 }
        }
        enum Grid {
            static var cornerRadius: CGFloat { 10 }
            static var dateFont: Font { .subheadline.weight(.regular) }
            static var dateLineLimit: Int { 1 }
            static var dateStyle: Color { .secondary }
            static var headerFont: Font { .title2.weight(.bold) }
            static var headerLineLimit: Int { 2 }
            static var headerStyle: Color { .primary }
            static var horizontalSpacing: CGFloat { 20 }
            static var verticalSpacing: CGFloat { 25 }
            static var width: CGFloat { 170 }
        }
        enum AlbumCard {
            static var cornerRadius: CGFloat { 8 }
            static var imageAspectRatio: CGFloat { 1 }
            static var cardWidth: CGFloat { 170 }
            static var textFrameHeight: CGFloat { 55 }
            static var titleFont: Font { .system(size: 13, weight: .medium) }
            static var titleLineLimit: Int { 1 }
            static var artistFont: Font { .system(size: 13, weight: .regular) }
            static var artistColor: Color { .secondary }
            static var artistLineLimit: Int { 1 }
            static var horizontalPadding: CGFloat { 0 }
            static var bottomPadding: CGFloat { 12 }
        }
        enum List {
            static var contentFont: Font { .body.weight(.regular) }
            static var contentLineLimit: Int { 1 }
            static var contentStyle: Color { .primary }
            static var cornerRadius: CGFloat { 10 }
            static var dateFont: Font { .subheadline.weight(.regular) }
            static var dateStyle: Color { .secondary }
            static var headerFont: Font { .title3.weight(.bold) }
            static var headerLineLimit: Int { 1 }
            static var headerStyle: Color { .primary }
            static var verticalSpacing: CGFloat { 12 }
            static var width: CGFloat { 200 }
        }
        enum Search {
            static var cornerRadius: CGFloat = 10
            static var horizontalSpacing: CGFloat = 12
            static var strokeColor: Color { .secondary.opacity(0.3) }
            static var strokeWidth: CGFloat { 0.5 }
            static var textStyle: PlainTextFieldStyle { .plain }
            static var verticalSpacing: CGFloat = 8
            static var width: CGFloat = 200
        }
        enum Settings {
            static var subtextFont: Font { .footnote }
            static var subtextStyle: Color { .secondary }
        }
    }
}
