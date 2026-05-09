// Models.swift

import Foundation
import SwiftUI

// MARK: - Track
struct Track: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var title: String
    var artist: String
    var album: String
    var albumArtURL: String?
    var duration: TimeInterval
    var source: TrackSource
    var streamURL: String?
    var isExplicit: Bool
    var isLiked: Bool = false

    var durationFormatted: String {
        let m = Int(duration) / 60
        let s = Int(duration) % 60
        return String(format: "%d:%02d", m, s)
    }

    enum CodingKeys: String, CodingKey {
        case id, title, artist, album, albumArtURL, duration, source, streamURL, isExplicit, isLiked
    }
}

enum TrackSource: String, Codable, Equatable, Hashable {
    case spotify
    case youtube
    case local

    var icon: String {
        switch self {
        case .spotify: return "s.circle.fill"
        case .youtube: return "play.rectangle.fill"
        case .local: return "music.note"
        }
    }

    var color: Color {
        switch self {
        case .spotify: return Color(hex: "#1DB954")
        case .youtube: return Color(hex: "#FF0000")
        case .local: return .purple
        }
    }
}

// MARK: - Playlist
struct Playlist: Identifiable, Codable {
    let id: String
    var name: String
    var description: String?
    var coverURL: String?
    var tracks: [Track]
    var owner: String
    var isPublic: Bool
    var source: TrackSource

    var totalDuration: TimeInterval {
        tracks.reduce(0) { $0 + $1.duration }
    }

    var totalDurationFormatted: String {
        let total = Int(totalDuration)
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "\(h) hr \(m) min" }
        return "\(m) min"
    }
}

// MARK: - Artist
struct Artist: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var imageURL: String?
    var genres: [String]
    var popularity: Int
    var followers: Int
    var source: TrackSource
}

// MARK: - Album
struct Album: Identifiable, Codable {
    let id: String
    var name: String
    var artist: String
    var artistID: String
    var coverURL: String?
    var releaseDate: String
    var tracks: [Track]
    var source: TrackSource

    var year: String {
        String(releaseDate.prefix(4))
    }
}

// MARK: - SearchResult
struct SearchResult {
    var tracks: [Track]
    var artists: [Artist]
    var albums: [Album]
    var playlists: [Playlist]
}

// MARK: - PlayerQueue
struct PlayerQueue {
    var tracks: [Track] = []
    var currentIndex: Int = 0

    var currentTrack: Track? {
        guard !tracks.isEmpty, currentIndex < tracks.count else { return nil }
        return tracks[currentIndex]
    }

    var nextTrack: Track? {
        guard currentIndex + 1 < tracks.count else { return nil }
        return tracks[currentIndex + 1]
    }

    mutating func advance() {
        if currentIndex < tracks.count - 1 {
            currentIndex += 1
        }
    }

    mutating func retreat() {
        if currentIndex > 0 {
            currentIndex -= 1
        }
    }
}

// MARK: - RepeatMode
enum RepeatMode: CaseIterable {
    case off, all, one

    var icon: String {
        switch self {
        case .off: return "repeat"
        case .all: return "repeat"
        case .one: return "repeat.1"
        }
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Sample Data
extension Track {
    static let sample = Track(
        id: "sample-1",
        title: "Blinding Lights",
        artist: "The Weeknd",
        album: "After Hours",
        albumArtURL: "https://i.scdn.co/image/ab67616d0000b273ef017e899c0547a1a5cde6b0",
        duration: 200,
        source: .spotify,
        isExplicit: false
    )
}

extension Playlist {
    static let samples: [Playlist] = [
        Playlist(id: "1", name: "Chill Vibes", description: "Perfect for relaxing", coverURL: nil, tracks: [], owner: "You", isPublic: false, source: .spotify),
        Playlist(id: "2", name: "Workout Mix", description: "Get pumped", coverURL: nil, tracks: [], owner: "You", isPublic: false, source: .spotify),
        Playlist(id: "3", name: "Late Night Drive", description: "Nighttime essentials", coverURL: nil, tracks: [], owner: "You", isPublic: false, source: .spotify),
    ]
}
