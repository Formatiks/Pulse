// SearchView.swift
// Combined Spotify + YouTube search with tabs

import SwiftUI

struct SearchView: View {
    @EnvironmentObject var spotify: SpotifyManager
    @EnvironmentObject var youtube: YouTubeManager
    @EnvironmentObject var player: MusicPlayerManager

    @State private var query = ""
    @State private var source: SearchSource = .spotify
    @State private var debounceTask: Task<Void, Never>?
    @FocusState private var isSearchFocused: Bool

    enum SearchSource: String, CaseIterable {
        case spotify = "Spotify"
        case youtube = "YouTube"
    }

    private var isEmpty: Bool { query.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ── Search Bar ──────────────────────────────────────
                HStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Artists, songs, podcasts…", text: $query)
                            .focused($isSearchFocused)
                            .submitLabel(.search)
                            .onSubmit { performSearch() }
                            .onChange(of: query) { _, new in
                                debounceSearch(new)
                            }
                        if !query.isEmpty {
                            Button {
                                query = ""
                                spotify.searchResults = SearchResult(tracks: [], artists: [], albums: [], playlists: [])
                                youtube.searchResults = []
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background {
                        if #available(iOS 26, *) {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(.regularMaterial)
                                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
                        } else {
                            RoundedRectangle(cornerRadius: 14).fill(.regularMaterial)
                        }
                    }

                    if isSearchFocused {
                        Button("Cancel") {
                            isSearchFocused = false
                            query = ""
                        }
                        .font(.system(size: 16))
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 12)
                .animation(.easeInOut(duration: 0.2), value: isSearchFocused)

                // ── Source Picker ───────────────────────────────────
                if !isEmpty {
                    Picker("Source", selection: $source) {
                        ForEach(SearchSource.allCases, id: \.self) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }

                // ── Results ─────────────────────────────────────────
                if isEmpty {
                    BrowseCategoriesView()
                } else {
                    resultsContent
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    @ViewBuilder
    private var resultsContent: some View {
        let isLoading = source == .spotify ? spotify.isSearching : youtube.isSearching
        let results: [Track] = source == .spotify
            ? spotify.searchResults.tracks
            : youtube.searchResults

        if isLoading {
            VStack {
                Spacer()
                ProgressView()
                    .scaleEffect(1.5)
                Spacer()
            }
        } else if results.isEmpty {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("No results for "\(query)"")
                    .font(.system(size: 18, weight: .semibold))
                Text("Check the spelling, or try a different term.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                Spacer()
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(results) { track in
                        TrackRow(track: track)
                            .onTapGesture {
                                player.play(track: track, queue: results)
                            }
                    }
                }
                .padding(.bottom, 120)
            }
        }
    }

    private func debounceSearch(_ new: String) {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)  // 0.4s debounce
            guard !Task.isCancelled else { return }
            await performSearchAsync(new)
        }
    }

    private func performSearch() {
        Task { await performSearchAsync(query) }
    }

    private func performSearchAsync(_ q: String) async {
        switch source {
        case .spotify: await spotify.search(query: q)
        case .youtube: await youtube.search(query: q)
        }
    }
}

// MARK: - Track Row

struct TrackRow: View {
    var track: Track
    @EnvironmentObject var player: MusicPlayerManager

    var body: some View {
        HStack(spacing: 14) {
            AsyncImage(url: URL(string: track.albumArtURL ?? "")) { img in
                img.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle().fill(.gray.opacity(0.3))
                    .overlay(Image(systemName: "music.note").foregroundStyle(.white.opacity(0.5)))
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(track.title)
                        .font(.system(size: 15, weight: .medium))
                        .lineLimit(1)
                    if track.isExplicit {
                        Text("E")
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(.secondary.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 4) {
                    Image(systemName: track.source.icon)
                        .font(.system(size: 10))
                        .foregroundStyle(track.source.color)
                    Text(track.artist)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if player.currentTrack?.id == track.id {
                // Animated equalizer bars
                EqualizerBars(isPlaying: player.isPlaying)
            } else {
                Text(track.durationFormatted)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Button {
                // More options
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .padding(8)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(
            player.currentTrack?.id == track.id
                ? Color(hex: "#1DB954").opacity(0.07)
                : Color.clear
        )
    }
}

// MARK: - Equalizer Bars

struct EqualizerBars: View {
    var isPlaying: Bool
    @State private var heights: [CGFloat] = [0.4, 0.7, 0.5]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(Color(hex: "#1DB954"))
                    .frame(width: 3, height: 16 * heights[i])
                    .animation(
                        isPlaying
                            ? .easeInOut(duration: 0.4 + Double(i) * 0.1)
                              .repeatForever(autoreverses: true)
                            : .default,
                        value: heights[i]
                    )
            }
        }
        .frame(width: 16, height: 16)
        .onAppear { animateBars() }
        .onChange(of: isPlaying) { _, _ in animateBars() }
    }

    private func animateBars() {
        guard isPlaying else {
            heights = [0.3, 0.5, 0.3]
            return
        }
        Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
            heights = heights.map { _ in CGFloat.random(in: 0.3...1.0) }
        }
    }
}

// MARK: - Browse Categories

struct BrowseCategoriesView: View {
    private let categories: [(String, String, Color)] = [
        ("Pop", "music.note", .pink),
        ("Hip-Hop", "headphones", .orange),
        ("Electronic", "waveform", .cyan),
        ("Rock", "guitars.fill", .red),
        ("R&B", "heart.fill", .purple),
        ("Latin", "star.fill", .yellow),
        ("Jazz", "music.quarternote.3", .teal),
        ("Classical", "pianokeys", .indigo),
        ("Podcasts", "mic.fill", .brown),
        ("New Releases", "sparkles", Color(hex: "#1DB954")),
    ]

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Browse categories")
                    .font(.system(size: 18, weight: .bold))
                    .padding(.horizontal)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(categories, id: \.0) { cat in
                        ZStack(alignment: .bottomLeading) {
                            cat.2.gradient
                            VStack {
                                Spacer()
                                HStack {
                                    Text(cat.0)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(14)
                                    Spacer()
                                    Image(systemName: cat.1)
                                        .font(.system(size: 32))
                                        .foregroundStyle(.white.opacity(0.5))
                                        .rotationEffect(.degrees(15))
                                        .padding(10)
                                }
                            }
                        }
                        .frame(height: 88)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 120)
        }
    }
}
