import SwiftUI

struct PlayerView: View {
    @EnvironmentObject var server: Server
    @EnvironmentObject var player: APlayer
    @State private var image: NSImage?

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 20) {
                // Album Art — fixed space always reserved
                ZStack {
                    if let image, player.current != nil {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                .frame(width: 40, height: 40)

                // Track Info — fixed width, invisible when nothing playing
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.current?.title ?? " ")
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(player.current?.artist ?? " ")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(width: 300, alignment: .leading)
                .opacity(player.current != nil ? 1 : 0)
                Spacer()

                // Controls
                HStack(spacing: 25) {
                    Button(action: { player.back() }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 18))
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        player.isPlaying ? player.pause() : player.resume()
                    }) {
                        Image(
                            systemName: player.isPlaying
                                ? "pause.fill" : "play.fill"
                        )
                        .font(.system(size: 24))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.space, modifiers: [])

                    Button(action: { player.forward() }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 18))
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                // Volume & More
                HStack(spacing: 15) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    Slider(value: .constant(0.5))
                        .frame(width: 100)
                        .controlSize(.small)

                    Button(action: {}) {
                        Image(systemName: "quote.bubble")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)

                    Button(action: {}) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.regularMaterial)
        }
        .task(id: player.current?.songID) {
            image = nil
            guard let coverArtID = player.current?.coverArt, !coverArtID.isEmpty
            else { return }
            let data = try? await server.getCoverArt(id: coverArtID)
            guard let data else { return }
            image = try? await ImageCacheManager.shared.image(
                for: coverArtID,
                data: data
            )
        }
    }
}
