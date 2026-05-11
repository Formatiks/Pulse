// HomeView.swift

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var spotify: SpotifyManager
    @EnvironmentObject var player: MusicPlayerManager
    @State private var greeting = ""

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 32) {
                    // ── Greeting ──────────────────────────────────
                    Text(greeting)
                        .font(.system(size: 28, weight: .bold))
                        .padding(.horizontal)

                    if !spotify.isAuthenticated {
                        SpotifyConnectBanner()
                            .padding(.horizontal)
                    } else {
                        // Quick Picks (2-column grid)
                        if !spotify.recentlyPlayed.isEmpty {
                            Section {
                                QuickPicksGrid(tracks: Array(spotify.recentlyPlayed.prefix(6)))
                                    .padding(.horizontal)
                            } header: {
                                SectionHeader(title: "Good picks")
                            }
                        }

                        // Recently Played
                        if !spotify.recentlyPlayed.isEmpty {
                            Section {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(spotify.recentlyPlayed.prefix(10)) { track in
                                            TrackCard(track: track)
                                                .onTapGesture {
                                                    player.play(track: track, queue: spotify.recentlyPlayed)
                                                }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            } header: {
                                SectionHeader(title: "Recently played")
                            }
                        }

                        // Top Tracks
                        if !spotify.topTracks.isEmpty {
                            Section {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(spotify.topTracks.prefix(10)) { track in
                                            TrackCard(track: track)
                                                .onTapGesture {
                                                    player.play(track: track, queue: spotify.topTracks)
                                                }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            } header: {
                                SectionHeader(title: "Your top tracks")
                            }
                        }

                        // Featured Playlists
                        if !spotify.featuredPlaylists.isEmpty {
                            Section {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(spotify.featuredPlaylists) { playlist in
                                            NavigationLink {
                                                PlaylistDetailView(playlist: playlist)
                                            } label: {
                                                PlaylistCard(playlist: playlist)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            } header: {
                                SectionHeader(title: "Featured")
                            }
                        }
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 120)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("pulse")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(hex: "#1DB954"))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    AsyncImage(url: URL(string: spotify.userProfile?.images?.first?.url ?? "")) { img in
                        img.resizable()
                    } placeholder: {
                        Circle().fill(.gray.opacity(0.3))
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                }
            }
        }
        .onAppear {
            updateGreeting()
        }
        .refreshable {
            await spotify.loadInitialData()
        }
    }

    private func updateGreeting() {
        let h = Calendar.current.component(.hour, from: Date())
        greeting = h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening"
    }
}

// MARK: - Spotify Connect Banner

struct SpotifyConnectBanner: View {
    @EnvironmentObject var spotify: SpotifyManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "s.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Color(hex: "#1DB954"))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Connect Spotify")
                        .font(.system(size: 18, weight: .bold))
                    Text("Stream music with your Premium account")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            }
            Button {
                spotify.authenticate()
            } label: {
                Text("Log in with Spotify")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(hex: "#1DB954"))
                    .clipShape(Capsule())
            }
        }
        .padding(20)
        .background {
            if #available(iOS 26, *) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.regularMaterial)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
            } else {
                RoundedRectangle(cornerRadius: 20).fill(.regularMaterial)
            }
        }
    }
}

// MARK: - Quick Picks Grid

struct QuickPicksGrid: View {
    var tracks: [Track]
    @EnvironmentObject var player: MusicPlayerManager

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(tracks) { track in
                Button {
                    player.play(track: track, queue: tracks)
                } label: {
                    HStack(spacing: 10) {
                        AsyncImage(url: URL(string: track.albumArtURL ?? "")) { img in
                            img.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle().fill(.gray.opacity(0.3))
                        }
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                        Text(track.title)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Spacer()
                    }
                    .padding(.trailing, 8)
                    .frame(maxWidth: .infinity)
                    .background {
                        if #available(iOS 26, *) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.regularMaterial)
                                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8))
                        } else {
                            RoundedRectangle(cornerRadius: 8).fill(.regularMaterial)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Track Card

struct TrackCard: View {
    var track: Track

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: URL(string: track.albumArtURL ?? "")) { img in
                img.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle().fill(.gray.opacity(0.3))
            }
            .frame(width: 140, height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Text(track.title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .frame(width: 140, alignment: .leading)

            Text(track.artist)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 140, alignment: .leading)
        }
        .frame(width: 140)
    }
}

// MARK: - Playlist Card

struct PlaylistCard: View {
    var playlist: Playlist

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: URL(string: playlist.coverURL ?? "")) { img in
                img.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                ZStack {
                    Rectangle().fill(Color.purple.opacity(0.3))
                    Image(systemName: "music.note.list")
                        .font(.system(size: 40))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .frame(width: 160, height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(playlist.name)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(2)
                .frame(width: 160, alignment: .leading)
        }
        .frame(width: 160)
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    var title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 20, weight: .bold))
            Spacer()
            if let actionTitle {
                Button(actionTitle) { action?() }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(hex: "#1DB954"))
            }
        }
        .padding(.horizontal)
    }
}
