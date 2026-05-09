// MusicPlayerManager.swift
// Core playback engine — wraps AVPlayer + Spotify playback

import AVFoundation
import Combine
import MediaPlayer
import SwiftUI

@MainActor
final class MusicPlayerManager: ObservableObject {
    static let shared = MusicPlayerManager()

    // MARK: - State
    @Published var currentTrack: Track?
    @Published var isPlaying = false
    @Published var progress: Double = 0      // 0…1
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var volume: Float = 1.0
    @Published var isShuffle = false
    @Published var repeatMode: RepeatMode = .off
    @Published var isLoading = false
    @Published var queue: PlayerQueue = PlayerQueue()
    @Published var showFullPlayer = false
    @Published var dominantColor: Color = .purple

    // MARK: - Private
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    private let colorExtractor = ColorExtractor()

    // MARK: - Setup

    private init() {
        setupRemoteControls()
        setupAudioSession()
    }

    private func setupAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    // MARK: - Queue Management

    func play(track: Track, queue: [Track] = []) {
        var q = queue.isEmpty ? [track] : queue
        let idx = q.firstIndex(where: { $0.id == track.id }) ?? 0
        var pq = PlayerQueue()
        pq.tracks = isShuffle ? q.shuffled() : q
        pq.currentIndex = idx
        self.queue = pq
        playCurrentQueueTrack()
    }

    func playPlaylist(_ playlist: Playlist, startTrack: Track? = nil) {
        var q = PlayerQueue()
        q.tracks = isShuffle ? playlist.tracks.shuffled() : playlist.tracks
        if let start = startTrack,
           let idx = q.tracks.firstIndex(where: { $0.id == start.id }) {
            q.currentIndex = idx
        }
        queue = q
        playCurrentQueueTrack()
    }

    func playNext() {
        switch repeatMode {
        case .one:
            seek(to: 0)
            player?.play()
        case .all:
            if queue.currentIndex == queue.tracks.count - 1 {
                queue.currentIndex = 0
            } else {
                queue.advance()
            }
            playCurrentQueueTrack()
        case .off:
            if queue.currentIndex < queue.tracks.count - 1 {
                queue.advance()
                playCurrentQueueTrack()
            } else {
                isPlaying = false
            }
        }
    }

    func playPrevious() {
        if currentTime > 3 {
            seek(to: 0)
        } else {
            queue.retreat()
            playCurrentQueueTrack()
        }
    }

    private func playCurrentQueueTrack() {
        guard let track = queue.currentTrack else { return }
        loadAndPlay(track: track)
    }

    // MARK: - Playback

    private func loadAndPlay(track: Track) {
        isLoading = true
        currentTrack = track
        updateNowPlayingInfo()

        // Extract dominant color from artwork
        Task {
            if let urlStr = track.albumArtURL, let url = URL(string: urlStr) {
                dominantColor = await colorExtractor.dominantColor(from: url) ?? .purple
            }
        }

        switch track.source {
        case .spotify:
            // Use Spotify SDK for premium playback; fallback to preview URL
            if let preview = track.streamURL, let url = URL(string: preview) {
                playURL(url, track: track)
            } else {
                Task {
                    await SpotifyManager.shared.playTrack(track)
                    isLoading = false
                    isPlaying = true
                }
            }
        case .youtube:
            Task {
                if let streamURL = track.streamURL, let url = URL(string: streamURL) {
                    playURL(url, track: track)
                } else if let resolved = await YouTubeManager.shared.resolveStreamURL(for: track),
                          let url = URL(string: resolved) {
                    playURL(url, track: track)
                }
                isLoading = false
            }
        case .local:
            if let path = track.streamURL, let url = URL(string: path) {
                playURL(url, track: track)
            }
        }
    }

    private func playURL(_ url: URL, track: Track) {
        stopCurrentPlayer()

        let item = AVPlayerItem(url: url)
        playerItem = item
        player = AVPlayer(playerItem: item)
        player?.volume = volume

        // Observe duration
        item.publisher(for: \.status)
            .filter { $0 == .readyToPlay }
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.duration = item.duration.seconds
                self.isLoading = false
                self.player?.play()
                self.isPlaying = true
            }
            .store(in: &cancellables)

        // Observe completion
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: item)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.playNext() }
            .store(in: &cancellables)

        // Time observer
        addTimeObserver()
    }

    private func stopCurrentPlayer() {
        player?.pause()
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        cancellables.removeAll()
        timeObserver = nil
        player = nil
        playerItem = nil
    }

    private func addTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            let current = time.seconds
            let dur = self.playerItem?.duration.seconds ?? 0
            if dur > 0 {
                self.currentTime = current
                self.progress = current / dur
                self.duration = dur
                self.updateNowPlayingInfo()
            }
        }
    }

    // MARK: - Controls

    func togglePlayPause() {
        if isPlaying {
            player?.pause()
        } else {
            player?.play()
        }
        isPlaying.toggle()
    }

    func seek(to value: Double) {
        let time = CMTime(seconds: value * duration, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func setVolume(_ v: Float) {
        volume = v
        player?.volume = v
    }

    func toggleShuffle() {
        isShuffle.toggle()
        if isShuffle {
            var shuffled = queue.tracks.shuffled()
            // Keep current track first
            if let current = queue.currentTrack,
               let idx = shuffled.firstIndex(where: { $0.id == current.id }) {
                shuffled.remove(at: idx)
                shuffled.insert(current, at: 0)
            }
            queue.tracks = shuffled
            queue.currentIndex = 0
        }
    }

    func cycleRepeat() {
        let modes = RepeatMode.allCases
        let idx = modes.firstIndex(of: repeatMode) ?? 0
        repeatMode = modes[(idx + 1) % modes.count]
    }

    // MARK: - Now Playing Info

    private func updateNowPlayingInfo() {
        guard let track = currentTrack else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPMediaItemPropertyAlbumTitle: track.album,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]

        if let urlStr = track.albumArtURL, let url = URL(string: urlStr) {
            Task {
                if let (data, _) = try? await URLSession.shared.data(from: url),
                   let image = UIImage(data: data) {
                    let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                    info[MPMediaItemPropertyArtwork] = artwork
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
                }
            }
        } else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        }
    }

    // MARK: - Remote Controls

    private func setupRemoteControls() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { [weak self] _ in
            self?.player?.play()
            self?.isPlaying = true
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            self?.player?.pause()
            self?.isPlaying = false
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.playNext()
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            self?.playPrevious()
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let e = event as? MPChangePlaybackPositionCommandEvent, let self {
                let ratio = e.positionTime / self.duration
                self.seek(to: ratio)
            }
            return .success
        }
    }
}

// MARK: - Color Extractor

final class ColorExtractor {
    func dominantColor(from url: URL) async -> Color? {
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let image = UIImage(data: data),
              let cgImage = image.cgImage else { return nil }

        // Sample pixels at corners + center for a quick dominant color
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        var rawData = [UInt8](repeating: 0, count: bytesPerRow * height)
        guard let context = CGContext(
            data: &rawData,
            width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Sample 5x5 grid
        var r = 0, g = 0, b = 0, count = 0
        let step = max(width / 5, 1)
        for x in stride(from: 0, to: width, by: step) {
            for y in stride(from: 0, to: height, by: step) {
                let idx = (y * width + x) * bytesPerPixel
                r += Int(rawData[idx]); g += Int(rawData[idx+1]); b += Int(rawData[idx+2])
                count += 1
            }
        }
        guard count > 0 else { return nil }
        return Color(
            .sRGB,
            red: Double(r / count) / 255,
            green: Double(g / count) / 255,
            blue: Double(b / count) / 255
        )
    }
}
