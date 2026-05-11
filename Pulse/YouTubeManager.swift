// YouTubeManager.swift
// YouTube integration via yt-dlp
//
// Architecture: A companion Python microserver runs yt-dlp locally on Mac/Linux
// and exposes a simple REST API. The iOS app calls it over localhost (or LAN).
//
// Run the server: python3 MuseYTServer.py
// Default: http://localhost:8765
//
// Alternatively, deploy MuseYTServer.py on a home server and point serverBase there.

import Foundation
import Combine

@MainActor
final class YouTubeManager: ObservableObject {
    static let shared = YouTubeManager()

    // Change to your server URL if running remotely
    private let serverBase = "http://mc.anozon.it:8765"
    private let session = URLSession.shared

    @Published var searchResults: [Track] = []
    @Published var isSearching = false
    @Published var serverReachable = false

    init() {
        Task { await checkServer() }
    }

    // MARK: - Server Health

    func checkServer() async {
        guard let url = URL(string: "\(serverBase)/health") else { return }
        do {
            let (_, response) = try await session.data(from: url)
            serverReachable = (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            serverReachable = false
        }
    }

    // MARK: - Search YouTube

    func search(query: String) async {
        guard !query.isEmpty else { return }
        isSearching = true
        defer { isSearching = false }

        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(serverBase)/search?q=\(encoded)&limit=20") else { return }
        do {
            let (data, _) = try await session.data(from: url)
            let results = try JSONDecoder().decode([YTSearchResult].self, from: data)
            searchResults = results.map { $0.toTrack() }
        } catch {
            print("YT search error: \(error)")
        }
    }

    // MARK: - Resolve Stream URL

    func resolveStreamURL(for track: Track) async -> String? {
        guard let url = URL(string: "\(serverBase)/stream/\(track.id)") else { return nil }
        do {
            let (data, _) = try await session.data(from: url)
            let response = try JSONDecoder().decode(YTStreamResponse.self, from: data)
            return response.url
        } catch {
            print("YT resolve error: \(error)")
            return nil
        }
    }

    // MARK: - Fetch Track Info

    func fetchTrackInfo(videoID: String) async -> Track? {
        guard let url = URL(string: "\(serverBase)/info/\(videoID)") else { return nil }
        do {
            let (data, _) = try await session.data(from: url)
            let result = try JSONDecoder().decode(YTSearchResult.self, from: data)
            return result.toTrack()
        } catch {
            return nil
        }
    }

    // MARK: - YouTube URL Parsing

    func extractVideoID(from urlString: String) -> String? {
        guard let url = URL(string: urlString) else { return nil }
        // youtu.be/ID
        if url.host == "youtu.be" { return url.pathComponents.dropFirst().first }
        // youtube.com/watch?v=ID
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let v = components.queryItems?.first(where: { $0.name == "v" })?.value {
            return v
        }
        return nil
    }
}

// MARK: - Response Models

struct YTSearchResult: Decodable {
    let id: String
    let title: String
    let channel: String
    let duration: Int       // seconds
    let thumbnail: String?
    let viewCount: Int?

    func toTrack() -> Track {
        Track(
            id: id,
            title: title,
            artist: channel,
            album: "YouTube",
            albumArtURL: thumbnail,
            duration: TimeInterval(duration),
            source: .youtube,
            isExplicit: false
        )
    }
}

struct YTStreamResponse: Decodable {
    let url: String
    let format: String
    let quality: String
}
