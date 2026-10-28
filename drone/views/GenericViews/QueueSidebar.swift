//
//  QueueSidebar.swift
//  drone
//
//  Right-side "Playing Next" panel, styled after Apple Music's queue sidebar.
//
//  Ordering note: drone's transport bar sits at the BOTTOM of the window, so
//  the queue reads bottom-up — the next song to play is at the BOTTOM of the
//  list, flowing upward away from the player bar. This is the reverse of Apple
//  Music's top-down order.
//

import SwiftUI

struct QueueSidebar: View {
    @EnvironmentObject var server: Server
    @EnvironmentObject var player: APlayer

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().opacity(0.4)
            content
        }
        .frame(width: 320)
        .background(.regularMaterial)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Playing Next")
                .font(.system(size: 15, weight: .bold))
            Spacer()
            Button(action: { player.clearQueue() }) {
                Text("Clear")
                    .font(.system(size: 13))
                    .foregroundStyle(player.upcoming.isEmpty ? .secondary : Color.accentColor)
            }
            .buttonStyle(.plain)
            .disabled(player.upcoming.isEmpty)

            Button(action: {
                withAnimation(.easeInOut(duration: 0.18)) {
                    player.showQueueSidebar = false
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.leading, 6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        // `upcoming` is in play order (first = next up). We display it reversed
        // so the next song lands at the bottom, nearest the transport bar.
        let upcoming = Array(player.upcoming.enumerated())
        if upcoming.isEmpty {
            VStack {
                Spacer()
                Text("No songs up next")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Reversed: last element (farthest in play order) first,
                        // next-up (offset 0) rendered last → at the bottom.
                        ForEach(upcoming.reversed(), id: \.element.id) { offset, song in
                            // queueIndex maps back into player.queue for jumpTo.
                            let queueIndex = player.curIndex + 1 + offset
                            QueueSidebarRow(song: song, queueIndex: queueIndex)
                                .id(offset)
                        }
                    }
                }
                .onAppear {
                    // Anchor to the bottom (the next song) when the panel opens.
                    proxy.scrollTo(0, anchor: .bottom)
                }
                .onChange(of: player.curIndex) { _, _ in
                    withAnimation { proxy.scrollTo(0, anchor: .bottom) }
                }
            }
        }
    }
}

// MARK: - Row

private struct QueueSidebarRow: View {
    let song: Song
    let queueIndex: Int
    @EnvironmentObject var server: Server
    @EnvironmentObject var player: APlayer
    @State private var isHovered = false

    var body: some View {
        Button(action: { player.jumpTo(index: queueIndex) }) {
            HStack(spacing: 10) {
                QueueArtwork(coverArt: song.coverArt)

                VStack(alignment: .leading, spacing: 2) {
                    Text(song.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if isHovered {
                    Button(action: { player.removeFromQueue(at: queueIndex) }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(formattedDuration(song.duration))
                        .font(.system(size: 12).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isHovered ? Color.primary.opacity(0.05) : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .overlay(alignment: .bottom) {
            Divider().opacity(0.12).padding(.leading, 60)
        }
    }

    private var subtitle: String {
        if song.album.isEmpty { return song.artist }
        return "\(song.artist) — \(song.album)"
    }

    private func formattedDuration(_ seconds: Int) -> String {
        "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }
}

// MARK: - Artwork

private struct QueueArtwork: View {
    let coverArt: String
    @EnvironmentObject var server: Server
    @State private var image: NSImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.secondary.opacity(0.12))
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary.opacity(0.4))
            }
        }
        .frame(width: 40, height: 40)
        .task(id: coverArt) {
            image = nil
            guard !coverArt.isEmpty else { return }
            guard let data = try? await server.getCoverArt(id: coverArt) else { return }
            image = try? await ImageCacheManager.shared.image(for: coverArt, data: data)
        }
    }
}
