// MuseApp.swift
// Entry point — import this project into Xcode 16+ (target iOS 18+/iOS 26)

import SwiftUI
import AVFoundation

@main
struct MuseApp: App {
    @StateObject private var playerManager = MusicPlayerManager.shared
    @StateObject private var spotifyManager = SpotifyManager.shared
    @StateObject private var youtubeManager = YouTubeManager.shared

    init() {
        configureAudioSession()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(playerManager)
                .environmentObject(spotifyManager)
                .environmentObject(youtubeManager)
                .onOpenURL { url in
                    // Handle Spotify OAuth callback
                    SpotifyManager.shared.handleAuthCallback(url: url)
                }
        }
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.allowAirPlay, .allowBluetooth, .allowBluetoothA2DP]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
    }
}
