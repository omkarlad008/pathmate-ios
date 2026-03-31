//
//  AppRootView.swift
//  Pathmate
//
//  Created by Omkar Lad on 14/10/2025.
//

import SwiftUI
import SwiftData
import WidgetKit

/// Routes either to onboarding (Welcome → Setup) or to the main tabs.
/// Uses SwiftData profile presence as the primary gate, with a small
/// @AppStorage fallback for compatibility.
struct AppRootView: View {
    @EnvironmentObject private var auth: AuthService
    /// Legacy onboarding flag kept for compatibility with older builds.
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding = false

    // SwiftData
    @Environment(\.modelContext) private var modelContext
    /// Presence of a profile indicates onboarding is complete.
    @Query private var profiles: [UserProfileEntity]
    @Environment(\.scenePhase) private var scenePhase

    /// One-shot profile passed to Home after Setup for greeting only.
    @State private var hydratedProfile: UserProfile? = nil

    var body: some View {
        Group {
            if hasProfile {
                ContentView(initialProfile: hydratedProfile)
            } else {
                OnboardingFlow { finalProfile in
                    // Save flag too (for safety), and keep a transient copy for first greeting
                    didCompleteOnboarding = true
                    hydratedProfile = finalProfile
                    // Safety: after Setup saved to SwiftData, push to Firestore once.
                    if let uid = auth.uid {
                        Task { await FirestoreProfileService.shared.pushFromLocal(uid: uid, modelContext: modelContext) }
                    }
                    // Seed the widget right after onboarding finishes
                    WidgetPublisher.publishFromSwiftData(context: modelContext)
                }
            }
        }
        // Start/refresh Firestore profile listener when a user is signed in
        .task(id: auth.uid) {
            if let uid = auth.uid {
                FirestoreProfileService.shared.start(uid: uid, modelContext: modelContext)
                FirestoreTaskStateService.shared.start(uid: uid, modelContext: modelContext)
            } else {
                FirestoreProfileService.shared.stop()
                FirestoreTaskStateService.shared.stop()
            }
        }
    }
    /// `true` when SwiftData has a saved `UserProfileEntity`.
    private var hasProfile: Bool { !profiles.isEmpty }
}

/// A tiny wrapper that chains Welcome → Setup using your existing screens.
private struct OnboardingFlow: View {
    @State private var showWelcome = true
    @State private var profile = UserProfile()
    /// Callback fired after Setup saves; used to seed widget and Firestore.
    let onFinished: (UserProfile) -> Void

    var body: some View {
        if showWelcome {
            WelcomeView { showWelcome = false }
        } else {
            SetupView(profile: $profile) {
                onFinished(profile)
            }
        }
    }
}
