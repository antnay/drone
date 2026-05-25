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
    @Published var currentTime: Double = 0
    @Published var isShuffling: Bool = false
    @Published var volume: Float = 1.0 {
        didSet {
            player.volume = volume
            UserDefaults.standard.set(volume, forKey: "playerVolume")
        }
    }

    var currentDuration: Double { Double(current?.duration ?? 0) }

    var shuffler = LibraryShuffler()

    private let player = AVPlayer()
    private var timeObserver: Any?
    var server: Server?

    init(server: Server? = nil) {
        self.current = nil
        self.isPlaying = false
        self.queue = []
        self.curIndex = 0
        self.server = server

        let saved = UserDefaults.standard.float(forKey: "playerVolume")
        let initialVolume: Float = saved > 0 ? saved : 1.0
        self.volume = initialVolume
        player.volume = initialVolume

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self else { return }
            let seconds = time.seconds
            if !seconds.isNaN && !seconds.isInfinite {
                self.currentTime = seconds
            }
        }

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

    nonisolated deinit {
        if let observer = timeObserver {
            // AVPlayer.removeTimeObserver is safe to call from any thread
        }
    }

    func shuffleAlbum(_ songs: [Song]) {
        queue = songs.shuffled()
        curIndex = 0
        play()
    }

    func shuffleLibrary() async {
        guard let server, !isShuffling else { return }
        isShuffling = true
        defer { isShuffling = false }
        do {
            let songs = try await shuffler.shuffle(server: server)
            queue = songs
            curIndex = 0
            play()
        } catch {
            Server.logger.error("Library shuffle failed: \(error.localizedDescription)")
        }
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
        currentTime = 0

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

    func back() {
        Server.logger.debug("back")
        guard curIndex - 1 >= 0 else { return }
        curIndex -= 1
        play()
    }

    func jumpTo(index: Int) {
        guard index >= 0, index < queue.count else { return }
        curIndex = index
        play()
    }

    func addNext(song: Song) {
        if queue.isEmpty {
            queue = [song]; curIndex = 0; play()
        } else {
            queue.insert(song, at: curIndex + 1)
        }
    }

    func addToQueue(song: Song) {
        if queue.isEmpty {
            queue = [song]; curIndex = 0; play()
        } else {
            queue.append(song)
        }
    }

    func removeFromQueue(at index: Int) {
        guard index >= 0, index < queue.count else { return }
        queue.remove(at: index)
        if index < curIndex {
            curIndex -= 1
        } else if index == curIndex {
            if curIndex >= queue.count { curIndex = max(0, queue.count - 1) }
            if !queue.isEmpty { play() } else { current = nil; isPlaying = false }
        }
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

        if let image = nowPlayingImage {
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in
                image
            }
            info[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    func seek(to time: Double) {
        player.seek(to: CMTime(seconds: time, preferredTimescale: 600))
        currentTime = time
        updateNowPlaying()
    }
}
