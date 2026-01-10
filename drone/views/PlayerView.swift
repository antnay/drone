import SwiftUI

struct PlayerView: View {
    @EnvironmentObject var server: Server
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 20) {
                // Album Art
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundStyle(.secondary)
                    )
                
                // Track Info
                VStack(alignment: .leading, spacing: 2) {
                    Text("Not Playing")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Select a song to start listening")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Controls
                HStack(spacing: 25) {
                    Button(action: {}) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 18))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {}) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 24))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {}) {
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
    }
}
