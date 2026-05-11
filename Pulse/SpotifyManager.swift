// SpotifyManager.swift
// Handles Spotify Web API + iOS SDK integration
// Requires: SpotifyiOS SDK via SPM — https://github.com/spotify/ios-sdk

import Foundation
import Combine
import UIKit

// MARK: - Config (fill these in Info.plist / Secrets.xcconfig)
private enum SpotifyConfig {
    /// Set in your Xcode project under Build Settings > User-Defined
    static let clientID     = Bundle.main.infoDictionary?["SPOTIFY_CLIENT_ID"] as? String ?? "f339a5189b8c40dda5cd0cdc84db4296"
    static let clientSecret = Bundle.main.infoDictionary?["SPOTIFY_CLIENT_SECRET"] as? String ?? "76e3d34ef63249fc8a5526a8669a2281"
    static let redirectURI  = Bundle.main.infoDictionary?["SPOTIFY_REDIRECT_URI"] as? String ?? "muse://spotify-callback"
    static let scopes       = "streaming user-read-playback-state user-modify-playback-state user-read-currently-playing user-library-read user-library-modify playlist-read-private user-top-read"
}

// MARK: - SpotifyManager
@MainActor
final class SpotifyManager: ObservableObject {
    static let shared = SpotifyManager()

    // Auth state
    @Published var isAuthenticated = false
    @Published var accessToken: String?
    @Published var userProfile: SpotifyUser?

    // Content
    @Published var featuredPlaylists: [Playlist] = []
    @Published var recentlyPlayed: [Track] = []
    @Published var topTracks: [Track] = []
    @Published var userPlaylists: [Playlist] = []

    // Search
    @Published var searchResults: SearchResult = SearchResult(tracks: [], artists: [], albums: [], playlists: [])
    @Published var isSearching = false

    private var tokenExpiry: Date?
    private var refreshToken: String?
    private let session = URLSession.shared
    private let baseURL = "https://api.spotify.com/v1"
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Auth

    /// Opens Spotify login in Safari / ASWebAuthenticationSession
    func authenticate() {
        var components = URLComponents(string: "https://accounts.spotify.com/authorize")!
        components.queryItems = [
            .init(name: "client_id", value: SpotifyConfig.clientID),
            .init(name: "response_type", value: "code"),
            .init(name: "redirect_uri", value: SpotifyConfig.redirectURI),
            .init(name: "scope", value: SpotifyConfig.scopes),
            .init(name: "show_dialog", value: "false")
        ]
        guard let url = components.url else { return }
        UIApplication.shared.open(url)
    }

    func handleAuthCallback(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value
        else { return }
        Task { await exchangeCodeForToken(code: code) }
    }

    private func exchangeCodeForToken(code: String) async {
        guard let url = URL(string: "https://accounts.spotify.com/api/token") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let credentials = "\(SpotifyConfig.clientID):\(SpotifyConfig.clientSecret)"
            .data(using: .utf8)!.base64EncodedString()
        request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = "grant_type=authorization_code&code=\(code)&redirect_uri=\(SpotifyConfig.redirectURI)"
        request.httpBody = body.data(using: .utf8)

        do {
            let (data, _) = try await session.data(for: request)
            let response = try JSONDecoder().decode(SpotifyTokenResponse.self, from: data)
            accessToken = response.accessToken
            refreshToken = response.refreshToken
            tokenExpiry = Date().addingTimeInterval(TimeInterval(response.expiresIn))
            isAuthenticated = true
            await loadInitialData()
        } catch {
            print("Token exchange error: \(error)")
        }
    }

    private func refreshAccessToken() async {
        guard let refresh = refreshToken,
              let url = URL(string: "https://accounts.spotify.com/api/token") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let credentials = "\(SpotifyConfig.clientID):\(SpotifyConfig.clientSecret)"
            .data(using: .utf8)!.base64EncodedString()
        request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "grant_type=refresh_token&refresh_token=\(refresh)".data(using: .utf8)

        do {
            let (data, _) = try await session.data(for: request)
            let response = try JSONDecoder().decode(SpotifyTokenResponse.self, from: data)
            accessToken = response.accessToken
            tokenExpiry = Date().addingTimeInterval(TimeInterval(response.expiresIn))
        } catch {
            print("Token refresh error: \(error)")
        }
    }

    private func validToken() async -> String? {
        if let expiry = tokenExpiry, Date() >= expiry.addingTimeInterval(-60) {
            await refreshAccessToken()
        }
        return accessToken
    }

    // MARK: - API Requests

    private func apiRequest<T: Decodable>(path: String, queryItems: [URLQueryItem] = []) async throws -> T {
        guard let token = await validToken() else {
            throw SpotifyError.notAuthenticated
        }
        var components = URLComponents(string: "\(baseURL)\(path)")!
        if !queryItems.isEmpty { components.queryItems = queryItems }
        guard let url = components.url else { throw SpotifyError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode == 401 {
            await refreshAccessToken()
            return try await apiRequest(path: path, queryItems: queryItems)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - Load Data

    func loadInitialData() async {
        async let profile: Void = fetchUserProfile()
        async let featured: Void = fetchFeaturedPlaylists()
        async let recent: Void = fetchRecentlyPlayed()
        async let top: Void = fetchTopTracks()
        async let playlists: Void = fetchUserPlaylists()
        _ = await (profile, featured, recent, top, playlists)
    }

    private func fetchUserProfile() async {
        do {
            let profile: SpotifyUser = try await apiRequest(path: "/me")
            userProfile = profile
        } catch { print("Profile error: \(error)") }
    }

    func fetchFeaturedPlaylists() async {
        do {
            let response: SpotifyFeaturedPlaylistsResponse = try await apiRequest(
                path: "/browse/featured-playlists",
                queryItems: [.init(name: "limit", value: "20")]
            )
            featuredPlaylists = response.playlists.items.map { $0.toPlaylist() }
        } catch { print("Featured error: \(error)") }
    }

    func fetchRecentlyPlayed() async {
        do {
            let response: SpotifyRecentlyPlayedResponse = try await apiRequest(
                path: "/me/player/recently-played",
                queryItems: [.init(name: "limit", value: "50")]
            )
            recentlyPlayed = response.items.compactMap { $0.track?.toTrack() }
        } catch { print("Recent error: \(error)") }
    }

    func fetchTopTracks() async {
        do {
            let response: SpotifyTopTracksResponse = try await apiRequest(
                path: "/me/top/tracks",
                queryItems: [.init(name: "limit", value: "50"), .init(name: "time_range", value: "medium_term")]
            )
            topTracks = response.items.map { $0.toTrack() }
        } catch { print("Top tracks error: \(error)") }
    }

    func fetchUserPlaylists() async {
        do {
            let response: SpotifyPlaylistsResponse = try await apiRequest(
                path: "/me/playlists",
                queryItems: [.init(name: "limit", value: "50")]
            )
            userPlaylists = response.items.map { $0.toPlaylist() }
        } catch { print("Playlists error: \(error)") }
    }

    func fetchPlaylistTracks(_ playlistID: String) async -> [Track] {
        do {
            let response: SpotifyPlaylistTracksResponse = try await apiRequest(
                path: "/playlists/\(playlistID)/tracks",
                queryItems: [.init(name: "limit", value: "100")]
            )
            return response.items.compactMap { $0.track?.toTrack() }
        } catch {
            print("Playlist tracks error: \(error)")
            return []
        }
    }

    // MARK: - Search

    func search(query: String) async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSearching = true
        do {
            let response: SpotifySearchResponse = try await apiRequest(
                path: "/search",
                queryItems: [
                    .init(name: "q", value: query),
                    .init(name: "type", value: "track,artist,album,playlist"),
                    .init(name: "limit", value: "20")
                ]
            )
            searchResults = SearchResult(
                tracks: response.tracks?.items.map { $0.toTrack() } ?? [],
                artists: response.artists?.items.map { $0.toArtist() } ?? [],
                albums: response.albums?.items.map { $0.toAlbum() } ?? [],
                playlists: response.playlists?.items.map { $0.toPlaylist() } ?? []
            )
        } catch { print("Search error: \(error)") }
        isSearching = false
    }

    // MARK: - Playback Control

    func playTrack(_ track: Track, in context: String? = nil) async {
        guard let token = await validToken(),
              let url = URL(string: "\(baseURL)/me/player/play") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = ["uris": ["spotify:track:\(track.id)"]]
        if let ctx = context { body["context_uri"] = ctx }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        _ = try? await session.data(for: request)
    }

    func toggleLike(track: Track) async -> Bool {
        guard let token = await validToken() else { return false }
        let method = track.isLiked ? "DELETE" : "PUT"
        guard let url = URL(string: "\(baseURL)/me/tracks?ids=\(track.id)") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        _ = try? await session.data(for: request)
        return !track.isLiked
    }
}

// MARK: - Errors
enum SpotifyError: Error {
    case notAuthenticated
    case invalidURL
    case decodingFailed
}

// MARK: - Spotify API Response Models

struct SpotifyTokenResponse: Decodable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let refreshToken: String?
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
    }
}

struct SpotifyUser: Decodable {
    let id: String
    let displayName: String?
    let email: String?
    let images: [SpotifyImage]?
    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case email
        case images
    }
}

struct SpotifyImage: Decodable {
    let url: String
    let width: Int?
    let height: Int?
}

struct SpotifyTrackObject: Decodable {
    let id: String
    let name: String
    let artists: [SpotifyArtistSimple]
    let album: SpotifyAlbumSimple
    let durationMs: Int
    let explicit: Bool
    let previewUrl: String?
    enum CodingKeys: String, CodingKey {
        case id, name, artists, album, explicit
        case durationMs = "duration_ms"
        case previewUrl = "preview_url"
    }
    func toTrack() -> Track {
        Track(
            id: id,
            title: name,
            artist: artists.first?.name ?? "Unknown",
            album: album.name,
            albumArtURL: album.images?.first?.url,
            duration: TimeInterval(durationMs) / 1000,
            source: .spotify,
            streamURL: previewUrl,
            isExplicit: explicit
        )
    }
}

struct SpotifyArtistSimple: Decodable {
    let id: String
    let name: String
}

struct SpotifyAlbumSimple: Decodable {
    let id: String
    let name: String
    let images: [SpotifyImage]?
    let releaseDate: String?
    enum CodingKeys: String, CodingKey {
        case id, name, images
        case releaseDate = "release_date"
    }
}

struct SpotifyArtistFull: Decodable {
    let id: String
    let name: String
    let images: [SpotifyImage]?
    let genres: [String]?
    let popularity: Int?
    let followers: SpotifyFollowers?
    func toArtist() -> Artist {
        Artist(
            id: id, name: name,
            imageURL: images?.first?.url,
            genres: genres ?? [],
            popularity: popularity ?? 0,
            followers: followers?.total ?? 0,
            source: .spotify
        )
    }
}

struct SpotifyFollowers: Decodable { let total: Int }

struct SpotifyAlbumFull: Decodable {
    let id: String
    let name: String
    let artists: [SpotifyArtistSimple]
    let images: [SpotifyImage]?
    let releaseDate: String?
    enum CodingKeys: String, CodingKey {
        case id, name, artists, images
        case releaseDate = "release_date"
    }
    func toAlbum() -> Album {
        Album(
            id: id, name: name,
            artist: artists.first?.name ?? "Unknown",
            artistID: artists.first?.id ?? "",
            coverURL: images?.first?.url,
            releaseDate: releaseDate ?? "",
            tracks: [], source: .spotify
        )
    }
}

struct SpotifyPlaylistSimple: Decodable {
    let id: String
    let name: String
    let description: String?
    let images: [SpotifyImage]?
    let owner: SpotifyOwner?
    let `public`: Bool?
    func toPlaylist() -> Playlist {
        Playlist(
            id: id, name: name,
            description: description,
            coverURL: images?.first?.url,
            tracks: [],
            owner: owner?.displayName ?? owner?.id ?? "Unknown",
            isPublic: `public` ?? false,
            source: .spotify
        )
    }
}

struct SpotifyOwner: Decodable {
    let id: String
    let displayName: String?
    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
    }
}

// Paged responses
struct SpotifyPaging<T: Decodable>: Decodable { let items: [T] }

struct SpotifyFeaturedPlaylistsResponse: Decodable {
    let playlists: SpotifyPaging<SpotifyPlaylistSimple>
}
struct SpotifyRecentlyPlayedItem: Decodable {
    let track: SpotifyTrackObject?
}
struct SpotifyRecentlyPlayedResponse: Decodable {
    let items: [SpotifyRecentlyPlayedItem]
}
struct SpotifyTopTracksResponse: Decodable {
    let items: [SpotifyTrackObject]
}
struct SpotifyPlaylistsResponse: Decodable {
    let items: [SpotifyPlaylistSimple]
}
struct SpotifyPlaylistTrackItem: Decodable {
    let track: SpotifyTrackObject?
}
struct SpotifyPlaylistTracksResponse: Decodable {
    let items: [SpotifyPlaylistTrackItem]
}
struct SpotifySearchResponse: Decodable {
    let tracks: SpotifyPaging<SpotifyTrackObject>?
    let artists: SpotifyPaging<SpotifyArtistFull>?
    let albums: SpotifyPaging<SpotifyAlbumFull>?
    let playlists: SpotifyPaging<SpotifyPlaylistSimple>?
}
