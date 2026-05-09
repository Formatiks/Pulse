// ContentView.swift
// Root navigation + mini player overlay

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var player: MusicPlayerManager
    @EnvironmentObject var spotify: SpotifyManager
    @State private var selectedTab: Tab = .home

    enum Tab: Hashable {
        case home, search, library
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem { Label("Home", systemImage: "house.fill") }
                    .tag(Tab.home)

                SearchView()
                    .tabItem { Label("Search", systemImage: "magnifyingglass") }
                    .tag(Tab.search)

                LibraryView()
                    .tabItem { Label("Library", systemImage: "square.stack.fill") }
                    .tag(Tab.library)
            }
            .tint(Color(hex: "#1DB954"))

            // Mini player sits above tab bar
            if player.currentTrack != nil && !player.showFullPlayer {
                MiniPlayerView()
                    .padding(.horizontal, 12)
                    .padding(.bottom, 60)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $player.showFullPlayer) {
            FullPlayerView()
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: player.currentTrack)
    }
}

// MARK: - Mini Player

struct MiniPlayerView: View {
    @EnvironmentObject var player: MusicPlayerManager

    var body: some View {
        Button {
            player.showFullPlayer = true
        } label: {
            HStack(spacing: 14) {
                // Artwork
                AsyncImage(url: URL(string: player.currentTrack?.albumArtURL ?? "")) { img in
                    img.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(.gray.opacity(0.3))
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.currentTrack?.title ?? "")
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    Text(player.currentTrack?.artist ?? "")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Controls
                HStack(spacing: 18) {
                    Button { player.playPrevious() } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 18))
                    }
                    Button { player.togglePlayPause() } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 22))
                    }
                    Button { player.playNext() } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 18))
                    }
                }
                .foregroundStyle(.primary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                // iOS 26: Liquid Glass
                if #available(iOS 26, *) {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(.regularMaterial)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18))
                } else {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(.ultraThinMaterial)
                }
            }
            .overlay(alignment: .bottom) {
                // Progress line
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color(hex: "#1DB954"))
                        .frame(width: geo.size.width * player.progress, height: 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .clipShape(Capsule())
                }
                .frame(height: 2)
                .padding(.horizontal, 4)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
    }
}
