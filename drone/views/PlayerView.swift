import SwiftData
import SwiftUI

struct PlayerView: View {
    @EnvironmentObject var server: Server
    @EnvironmentObject var player: APlayer
    @EnvironmentObject var router: NavigationRouter
    @Environment(\.modelContext) private var modelContext
    @State private var image: NSImage?
    @State private var scrubValue: Double = 0
    @State private var isScrubbing = false
    @State private var showQueue = false

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 0) {
                trackInfo
                    .frame(maxWidth: .infinity, alignment: .leading)

                centerColumn
                    .frame(maxWidth: .infinity)

                rightControls
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(.regularMaterial)
        }
        .onChange(of: player.currentTime) { _, newTime in
            if !isScrubbing { scrubValue = newTime }
        }
        .onChange(of: player.current) { _, _ in
            scrubValue = 0
        }
        .task(id: player.current?.songID) {
            image = nil
            guard let id = player.current?.coverArt, !id.isEmpty else { return }
            if let data = try? await server.getCoverArt(id: id) {
                image = try? await ImageCacheManager.shared.image(for: id, data: data)
            }
        }
    }

    // MARK: - Left: art + track info

    private var trackInfo: some View {
        HStack(spacing: 12) {
            Button(action: { navigateToAlbum() }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.08))
                    if let image, player.current != nil {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .disabled(player.current == nil)

            VStack(alignment: .leading, spacing: 2) {
                Button(action: { navigateToAlbum() }) {
                    Text(player.current?.title ?? " ")
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)

                Button(action: { navigateToArtist() }) {
                    Text(player.current?.artist ?? " ")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .buttonStyle(.plain)

                Button(action: { navigateToAlbum() }) {
                    Text(player.current?.album ?? " ")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .buttonStyle(.plain)
            }
            .frame(width: 220, alignment: .leading)
            .opacity(player.current != nil ? 1 : 0)
        }
    }

    private func navigateToAlbum() {
        guard let albumId = player.current?.albumId, !albumId.isEmpty else { return }
        let descriptor = FetchDescriptor<Album>(
            predicate: #Predicate { $0.albumId == albumId }
        )
        guard let album = (try? modelContext.fetch(descriptor))?.first else { return }
        router.navigate(to: album)
    }

    private func navigateToArtist() {
        guard let artistId = player.current?.artistId, !artistId.isEmpty else { return }
        let descriptor = FetchDescriptor<Artist>(
            predicate: #Predicate { $0.artistID == artistId }
        )
        guard let artist = (try? modelContext.fetch(descriptor))?.first else { return }
        router.navigate(to: artist)
    }

    // MARK: - Center: controls + scrubber

    private var centerColumn: some View {
        VStack(spacing: 6) {
            HStack(spacing: 28) {
                Button(action: { player.back() }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)

                Button(action: {
                    player.isPlaying ? player.pause() : player.resume()
                }) {
                    Image(
                        systemName: player.isPlaying ? "pause.fill" : "play.fill"
                    )
                    .font(.system(size: 22))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.space, modifiers: [])

                Button(action: { player.forward() }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
            }

            scrubBar
        }
        .frame(maxWidth: 480)
    }

    private var scrubBar: some View {
        HStack(spacing: 6) {
            Text(formatTime(isScrubbing ? scrubValue : player.currentTime))
                .font(.system(size: 10).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .trailing)

            Slider(
                value: $scrubValue,
                in: 0...max(1, player.currentDuration)
            ) { editing in
                isScrubbing = editing
                if !editing {
                    player.seek(to: scrubValue)
                }
            }
            .controlSize(.small)
            .disabled(player.current == nil)

            Text(formatTime(player.currentDuration))
                .font(.system(size: 10).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .leading)
        }
    }

    // MARK: - Right: volume

    private var rightControls: some View {
        HStack(spacing: 8) {
            Image(systemName: volumeIcon)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 16)

            Slider(value: Binding(
                get: { Double(player.volume) },
                set: { player.volume = Float($0) }
            ), in: 0...1)
            .frame(width: 88)
            .controlSize(.small)

            Button(action: { showQueue.toggle() }) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 14))
                    .foregroundStyle(showQueue ? Color.accentColor : .primary)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showQueue, arrowEdge: .top) {
                QueuePopover()
                    .environmentObject(player)
            }
        }
    }

    // MARK: - Helpers

    private var volumeIcon: String {
        switch player.volume {
        case 0: return "speaker.slash.fill"
        case ..<0.33: return "speaker.wave.1.fill"
        case ..<0.66: return "speaker.wave.2.fill"
        default: return "speaker.wave.3.fill"
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let s = Int(seconds)
        let m = s / 60
        if m >= 60 {
            return "\(m / 60):\(String(format: "%02d", m % 60)):\(String(format: "%02d", s % 60))"
        }
        return "\(m):\(String(format: "%02d", s % 60))"
    }
}

// MARK: - Queue Popover

struct QueuePopover: View {
    @EnvironmentObject var player: APlayer
    @State private var hoveredIndex: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Queue")
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            Divider()

            if player.queue.isEmpty {
                Text("No songs in queue")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 32)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(player.queue.enumerated()), id: \.offset) { index, song in
                                queueRow(song: song, index: index)
                                    .id(index)
                            }
                        }
                    }
                    .frame(height: 340)
                    .onAppear {
                        let target = max(0, player.curIndex - 2)
                        proxy.scrollTo(target, anchor: .top)
                    }
                    .onChange(of: player.curIndex) { _, i in
                        withAnimation { proxy.scrollTo(max(0, i - 2), anchor: .top) }
                    }
                }
            }
        }
        .frame(width: 300)
    }

    private func queueRow(song: Song, index: Int) -> some View {
        let isCurrent = index == player.curIndex
        let isHovered = hoveredIndex == index
        return Button(action: { player.jumpTo(index: index) }) {
            HStack(spacing: 10) {
                if isCurrent {
                    Image(systemName: "waveform")
                        .font(.system(size: 11))
                        .foregroundStyle(.accent)
                        .frame(width: 16)
                        .symbolEffect(.variableColor.iterative, isActive: player.isPlaying)
                } else {
                    Spacer().frame(width: 16)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(song.title)
                        .font(.system(size: 13, weight: isCurrent ? .semibold : .regular))
                        .foregroundStyle(isCurrent ? Color.accentColor : .primary)
                        .lineLimit(1)
                    Text(song.artist)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button(action: { player.removeFromQueue(at: index) }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .opacity(isHovered ? 1 : 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(isCurrent ? Color.accentColor.opacity(0.08) : (isHovered ? Color.primary.opacity(0.05) : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hoveredIndex = $0 ? index : nil }
    }
}
