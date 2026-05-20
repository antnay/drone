//
//  APlayer.swift
//  drone
//
//  Created by Anthony on 5/19/26.
//

import AVFoundation
import Combine
import MediaPlayer
import SwiftUI

@MainActor
class APlayer: ObservableObject {
    @Published var current: Song?
    @Published var nowPlayingImage: NSImage?
    @Published var isPlaying: Bool = false
    @Published var queue: [Song] = []
    @Published var curIndex: Int = 0

    private let player = AVPlayer()
    var server: Server?

    init(server: Server? = nil) {
        self.current = nil
        self.isPlaying = false
        self.queue = []
        self.curIndex = 0
        self.server = server
        setupCC()
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.forward()
            }
        }
    }

    func shuffleAlbum(_ songs: [Song]) {
        Server.logger.debug("shuffle album")
    }

    func playAlbum(songs: [Song], startingAt: Int = 0) {
        Server.logger.debug("play album")
        queue = songs
        curIndex = startingAt
        play()
    }

    func play() {
        Server.logger.debug("play")
        guard !queue.isEmpty else { return }

        player.pause()

        current = queue[curIndex]
        guard let current else { return }

        guard let url = server?.streamURL(for: current.songID) else { return }
        let playerItem = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: playerItem)
        player.play()
        isPlaying = true
        MPNowPlayingInfoCenter.default().playbackState = .playing

        Task {
            if !current.coverArt.isEmpty {
                if let data = try? await server?.getCoverArt(
                    id: current.coverArt
                ) {
                    nowPlayingImage = try? await ImageCacheManager.shared.image(
                        for: current.coverArt,
                        data: data
                    )
                }
            } else {
                nowPlayingImage = nil
            }
            updateNowPlaying()
        }
    }
    func pause() {
        Server.logger.debug("pause")
        guard current != nil else { return }
        self.player.pause()
        isPlaying = false
        MPNowPlayingInfoCenter.default().playbackState = .paused
        updateNowPlaying()
    }

    func resume() {
        Server.logger.debug("resume")
        guard current != nil else { return }
        self.player.play()
        isPlaying = true
        MPNowPlayingInfoCenter.default().playbackState = .playing
        updateNowPlaying()
    }

    func forward() {
        Server.logger.debug("forward")
        guard curIndex + 1 < queue.count else { return }
        curIndex += 1
        play()
    }

    // maybe no queue
    func back() {
        Server.logger.debug("back")
        guard curIndex - 1 >= 0 else { return }
        curIndex -= 1
        play()
    }

    private func setupCC() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            if self.isPlaying {
                self.pause()
            } else {
                self.resume()
            }
            return .success
        }

        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.forward()
            return .success
        }

        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.back()
            return .success
        }

        commandCenter.changePlaybackPositionCommand.addTarget {
            [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent
            else { return .commandFailed }
            self?.seek(to: event.positionTime)
            return .success
        }
    }

    func updateNowPlaying() {
        guard let song = current else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: song.title,
            MPMediaItemPropertyArtist: song.artist,
            MPMediaItemPropertyAlbumTitle: song.album,
            MPMediaItemPropertyPlaybackDuration: Double(song.duration),
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]

        // Add artwork if available
        if let image = nowPlayingImage {
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in
                image
            }
            info[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    var currentTime: Double {
        player.currentTime().seconds.isNaN ? 0 : player.currentTime().seconds
    }

    func seek(to time: Double) {
        player.seek(to: CMTime(seconds: time, preferredTimescale: 600))
        updateNowPlaying()
    }
}
