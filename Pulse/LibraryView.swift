// LibraryView.swift + PlaylistDetailView.swift

import SwiftUI

// MARK: - Library View

struct LibraryView: View {
    @EnvironmentObject var spotify: SpotifyManager
    @EnvironmentObject var player: MusicPlayerManager
    @State private var filterType: LibraryFilter = .all
    @State private var viewMode: ViewMode = .list

    enum LibraryFilter: String, CaseIterable {
        case all = "All"
        case playlists = "Playlists"
        case artists = "Artists"
        case albums = "Albums"
    }

    enum ViewMode {
        case list, grid
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(LibraryFilter.allCases, id: \.self) { f in
                            FilterChip(title: f.rawValue, isSelected: filterType == f) {
                                filterType = f
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                if spotify.isAuthenticated {
                    // Playlists list
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(spotify.userPlaylists) { playlist in
                                NavigationLink {
                                    PlaylistDetailView(playlist: playlist)
                                } label: {
                                    PlaylistRow(playlist: playlist)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.bottom, 120)
                    }
                } else {
                    VStack(spacing: 20) {
                        Spacer()
                        Image(systemName: "square.stack.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        Text("Your library lives here")
                            .font(.system(size: 22, weight: .bold))
                        Text("Connect Spotify to access your\nplaylists, artists, and albums.")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button {
                            spotify.authenticate()
                        } label: {
                            Text("Log in with Spotify")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 14)
                                .background(Color(hex: "#1DB954"))
                                .clipShape(Capsule())
                        }
                        Spacer()
                    }
                }
            }
            .navigationTitle("Your Library")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        // Create playlist
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .refreshable {
            await spotify.fetchUserPlaylists()
        }
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    var title: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color(hex: "#1DB954") : Color.primary.opacity(0.08))
                .foregroundStyle(isSelected ? .black : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Playlist Row

struct PlaylistRow: View {
    var playlist: Playlist

    var body: some View {
        HStack(spacing: 14) {
            AsyncImage(url: URL(string: playlist.coverURL ?? "")) { img in
                img.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                ZStack {
                    Rectangle().fill(Color.purple.opacity(0.3))
                    Image(systemName: "music.note.list")
                        .foregroundStyle(.white.opacity(0.6))
                        .font(.system(size: 20))
                }
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(.system(size: 16, weight: .medium))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Image(systemName: playlist.source.icon)
                        .font(.system(size: 10))
                        .foregroundStyle(playlist.source.color)
                    Text("\(playlist.tracks.isEmpty ? "Playlist" : "\(playlist.tracks.count) songs") • \(playlist.owner)")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}

// MARK: - Playlist Detail View

struct PlaylistDetailView: View {
    var playlist: Playlist
    @EnvironmentObject var player: MusicPlayerManager
    @EnvironmentObject var spotify: SpotifyManager
    @State private var tracks: [Track] = []
    @State private var isLoading = true
    @State private var scrollOffset: CGFloat = 0
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Header
                    PlaylistHeaderView(playlist: playlist, tracks: tracks)
                        .padding(.bottom, 8)

                    // Play + Shuffle bar
                    HStack(spacing: 16) {
                        Button {
                            if let first = tracks.first {
                                player.playPlaylist(Playlist(
                                    id: playlist.id, name: playlist.name,
                                    description: playlist.description,
                                    coverURL: playlist.coverURL,
                                    tracks: tracks,
                                    owner: playlist.owner, isPublic: playlist.isPublic,
                                    source: playlist.source
                                ))
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                Text("Play")
                            }
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(hex: "#1DB954"))
                            .clipShape(Capsule())
                        }

                        Button {
                            player.isShuffle = true
                            if let first = tracks.shuffled().first {
                                player.playPlaylist(Playlist(
                                    id: playlist.id, name: playlist.name,
                                    description: playlist.description,
                                    coverURL: playlist.coverURL,
                                    tracks: tracks,
                                    owner: playlist.owner, isPublic: playlist.isPublic,
                                    source: playlist.source
                                ))
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "shuffle")
                                Text("Shuffle")
                            }
                            .font(.system(size: 16, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.primary.opacity(0.08))
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 12)

                    if isLoading {
                        ProgressView()
                            .padding(40)
                    } else {
                        ForEach(Array(tracks.enumerated()), id: \.element.id) { idx, track in
                            TrackRow(track: track)
                                .onTapGesture {
                                    player.play(track: track, queue: tracks)
                                }
                        }
                    }
                }
                .padding(.bottom, 120)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            tracks = await spotify.fetchPlaylistTracks(playlist.id)
            isLoading = false
        }
    }
}

// MARK: - Playlist Header

struct PlaylistHeaderView: View {
    var playlist: Playlist
    var tracks: [Track]

    var body: some View {
        VStack(spacing: 16) {
            AsyncImage(url: URL(string: playlist.coverURL ?? "")) { img in
                img.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                ZStack {
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: "music.note.list")
                        .font(.system(size: 60))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .frame(width: 200, height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.3), radius: 20, y: 10)

            VStack(spacing: 6) {
                Text(playlist.name)
                    .font(.system(size: 22, weight: .bold))
                    .multilineTextAlignment(.center)

                if let desc = playlist.description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }

                HStack(spacing: 4) {
                    Image(systemName: playlist.source.icon)
                        .foregroundStyle(playlist.source.color)
                    Text(playlist.owner)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                    if !tracks.isEmpty {
                        Text("•")
                            .foregroundStyle(.tertiary)
                        Text("\(tracks.count) songs")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
    }
}
