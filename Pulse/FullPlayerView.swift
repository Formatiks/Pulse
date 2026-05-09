// FullPlayerView.swift
// Immersive now-playing screen with Liquid Glass (iOS 26) + animated artwork

import SwiftUI

struct FullPlayerView: View {
    @EnvironmentObject var player: MusicPlayerManager
    @Environment(\.dismiss) private var dismiss
    @State private var isDragging = false
    @State private var dragProgress: Double = 0
    @State private var artworkScale: CGFloat = 0.85

    private var displayProgress: Double {
        isDragging ? dragProgress : player.progress
    }

    var body: some View {
        ZStack {
            // ── Background ──────────────────────────────────────────────
            GeometryReader { geo in
                AsyncImage(url: URL(string: player.currentTrack?.albumArtURL ?? "")) { img in
                    img.resizable()
                       .aspectRatio(contentMode: .fill)
                       .frame(width: geo.size.width, height: geo.size.height)
                } placeholder: {
                    Rectangle().fill(player.dominantColor.gradient)
                }
                .blur(radius: 60)
                .saturation(1.6)
                .opacity(0.85)
                .ignoresSafeArea()
            }
            .overlay(Color.black.opacity(0.45).ignoresSafeArea())

            // ── Content ──────────────────────────────────────────────────
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(12)
                            .background {
                                if #available(iOS 26, *) {
                                    Circle()
                                        .fill(.thinMaterial)
                                        .glassEffect(.regular, in: Circle())
                                } else {
                                    Circle().fill(.ultraThinMaterial)
                                }
                            }
                    }

                    Spacer()

                    VStack(spacing: 2) {
                        Text("Now Playing")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                            .textCase(.uppercase)
                            .tracking(1.5)
                        if let src = player.currentTrack?.source {
                            HStack(spacing: 4) {
                                Image(systemName: src.icon)
                                    .font(.system(size: 10))
                                Text(src.rawValue.capitalized)
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundStyle(src.color)
                        }
                    }

                    Spacer()

                    Menu {
                        Button("Add to Queue", systemImage: "text.badge.plus") {
                            // TODO
                        }
                        Button("Add to Playlist", systemImage: "plus.square.on.square") {
                            // TODO
                        }
                        Button("Share", systemImage: "square.and.arrow.up") {
                            // TODO
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(12)
                            .background {
                                if #available(iOS 26, *) {
                                    Circle()
                                        .fill(.thinMaterial)
                                        .glassEffect(.regular, in: Circle())
                                } else {
                                    Circle().fill(.ultraThinMaterial)
                                }
                            }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)

                Spacer()

                // ── Artwork ──────────────────────────────────────────────
                AsyncImage(url: URL(string: player.currentTrack?.albumArtURL ?? "")) { img in
                    img.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    ZStack {
                        Rectangle().fill(player.dominantColor.opacity(0.3))
                        Image(systemName: "music.note")
                            .font(.system(size: 80))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                .frame(width: 300, height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: player.dominantColor.opacity(0.6), radius: 40, y: 20)
                .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
                .scaleEffect(player.isPlaying ? 1.0 : 0.85)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: player.isPlaying)

                Spacer()

                // ── Track Info + Controls ─────────────────────────────────
                VStack(spacing: 0) {
                    // Track name + like
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(player.currentTrack?.title ?? "—")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                if player.currentTrack?.isExplicit == true {
                                    Text("E")
                                        .font(.system(size: 9, weight: .bold))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                        .background(.white.opacity(0.2))
                                        .clipShape(RoundedRectangle(cornerRadius: 3))
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                            }
                            Text(player.currentTrack?.artist ?? "—")
                                .font(.system(size: 16))
                                .foregroundStyle(.white.opacity(0.7))
                                .lineLimit(1)
                        }
                        Spacer()
                        LikeButton(track: player.currentTrack)
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 28)

                    // Progress Bar
                    ProgressBarView(
                        progress: displayProgress,
                        duration: player.duration,
                        currentTime: player.currentTime,
                        isDragging: $isDragging,
                        dragProgress: $dragProgress
                    ) { newValue in
                        player.seek(to: newValue)
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 28)

                    // Playback Controls
                    PlaybackControlsView()
                        .padding(.horizontal, 28)
                        .padding(.bottom, 20)

                    // Volume + Extra Controls
                    VolumeAndExtrasView()
                        .padding(.horizontal, 28)
                        .padding(.bottom, 32)
                }
                .background {
                    if #available(iOS 26, *) {
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .glassEffect(.regular.tint(player.dominantColor.opacity(0.1)),
                                         in: RoundedRectangle(cornerRadius: 32, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .fill(.ultraThinMaterial)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .padding(.horizontal, 12)
                .padding(.bottom, 16)
            }
        }
        .ignoresSafeArea(edges: .top)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Progress Bar

struct ProgressBarView: View {
    var progress: Double
    var duration: TimeInterval
    var currentTime: TimeInterval
    @Binding var isDragging: Bool
    @Binding var dragProgress: Double
    var onSeek: (Double) -> Void

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.2))
                        .frame(height: isDragging ? 6 : 4)

                    Capsule()
                        .fill(.white)
                        .frame(width: geo.size.width * progress, height: isDragging ? 6 : 4)

                    // Thumb
                    Circle()
                        .fill(.white)
                        .frame(width: isDragging ? 18 : 0)
                        .shadow(radius: 3)
                        .offset(x: geo.size.width * progress - (isDragging ? 9 : 0))
                }
                .frame(maxHeight: .infinity, alignment: .center)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { val in
                            isDragging = true
                            dragProgress = max(0, min(1, val.location.x / geo.size.width))
                        }
                        .onEnded { _ in
                            onSeek(dragProgress)
                            isDragging = false
                        }
                )
            }
            .frame(height: 24)
            .animation(.easeInOut(duration: 0.15), value: isDragging)

            HStack {
                Text(timeString(currentTime))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Text(timeString(duration))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }

    private func timeString(_ t: TimeInterval) -> String {
        guard t.isFinite else { return "-:--" }
        let m = Int(t) / 60; let s = Int(t) % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Playback Controls

struct PlaybackControlsView: View {
    @EnvironmentObject var player: MusicPlayerManager

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // Shuffle
            Button { player.toggleShuffle() } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 20))
                    .foregroundStyle(player.isShuffle ? Color(hex: "#1DB954") : .white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)

            // Previous
            Button { player.playPrevious() } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)

            // Play / Pause
            Button { player.togglePlayPause() } label: {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 72, height: 72)
                        .shadow(color: .white.opacity(0.3), radius: 12)
                    if player.isLoading {
                        ProgressView()
                            .tint(.black)
                            .scaleEffect(1.2)
                    } else {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(.black)
                            .offset(x: player.isPlaying ? 0 : 2)
                    }
                }
            }
            .frame(maxWidth: .infinity)

            // Next
            Button { player.playNext() } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)

            // Repeat
            Button { player.cycleRepeat() } label: {
                Image(systemName: player.repeatMode.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(player.repeatMode == .off ? .white.opacity(0.7) : Color(hex: "#1DB954"))
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Volume + Extras

struct VolumeAndExtrasView: View {
    @EnvironmentObject var player: MusicPlayerManager

    var body: some View {
        VStack(spacing: 20) {
            // Volume
            HStack(spacing: 12) {
                Image(systemName: "speaker.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.6))
                Slider(value: Binding(
                    get: { Double(player.volume) },
                    set: { player.setVolume(Float($0)) }
                ))
                .tint(.white)
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.6))
            }

            // Extras
            HStack {
                Button { } label: {
                    Image(systemName: "airplayaudio")
                        .font(.system(size: 20))
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                Button { } label: {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 20))
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                Button { } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 20))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Like Button

struct LikeButton: View {
    var track: Track?
    @State private var isLiked = false
    @State private var animating = false

    var body: some View {
        Button {
            isLiked.toggle()
            animating = true
            Task {
                if let t = track {
                    isLiked = await SpotifyManager.shared.toggleLike(track: t)
                }
                animating = false
            }
        } label: {
            Image(systemName: isLiked ? "heart.fill" : "heart")
                .font(.system(size: 26))
                .foregroundStyle(isLiked ? Color(hex: "#1DB954") : .white.opacity(0.7))
                .scaleEffect(animating ? 1.3 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: animating)
        }
        .onAppear { isLiked = track?.isLiked ?? false }
    }
}
