// PulseApp.swift
// App entry point

import SwiftUI
import AVFoundation

@main
struct PulseApp: App {
    @StateObject private var playerManager  = MusicPlayerManager.shared
    @StateObject private var spotifyManager = SpotifyManager.shared
    @StateObject private var youtubeManager = YouTubeManager.shared

    init() {
        PulseSetup.configureAudioSession()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(playerManager)
                .environmentObject(spotifyManager)
                .environmentObject(youtubeManager)
                .onOpenURL { SpotifyManager.shared.handleAuthCallback(url: $0) }
        }
    }
}

enum PulseSetup {
    static func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.allowAirPlay, .allowBluetoothHFP, .allowBluetoothA2DP]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
    }
}
