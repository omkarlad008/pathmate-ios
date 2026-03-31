//
//  ContentView.swift
//  Pathmate
//
//  Created by Omkar Lad on 27/8/2025.
//

// MARK: - Imports
// SwiftUI for navigation and tab composition.
import SwiftUI

/// **ContentView (Tabs only)**
///
/// Hosts the primary tab bar for the app: **Home**, **Journey**, **Planner**,
/// **Resources**, and **Profile**. Onboarding (Welcome → Setup) is handled by
/// ``AppRootView`` so this container focuses purely on navigation between
/// the main feature areas.
///
/// - SeeAlso: ``AppRootView``, ``HomeView``, ``JourneyView``, ``PlannerView``
struct ContentView: View {

    // MARK: - State
    /// Currently selected tab index in the `TabView`.
    @State private var selection = 0

    /// Optional profile snapshot for the first Home render post-onboarding.
    let initialProfile: UserProfile?

    // MARK: - Init
    init(initialProfile: UserProfile? = nil) {
        self.initialProfile = initialProfile
    }

    // MARK: - Body
    var body: some View {
        TabView(selection: $selection) {
            // Home
            HomeView(profile: initialProfile ?? UserProfile())
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)

            // Journey
            JourneyView()
                .tabItem { Label("Journey", systemImage: "checklist") }
                .tag(1)

            // Planner
            PlannerView()
                .tabItem { Label("Planner", systemImage: "calendar") }
                .tag(2)

            // Resources (placeholder for now)
//            NavigationStack {
//                PlaceholderScreen(title: "Resources",
//                                  subtitle: "More content to be added later")
//            }
//            .tabItem { Label("Resources", systemImage: "book.fill") }
//            .tag(3)
            
            // Profile
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(3)
        }
        .tint(.blue)
        // When user taps a task in the widget, jump to Planner tab.
        .onReceive(NotificationCenter.default.publisher(for: .openTaskFromWidget)) { note in
            selection = 2 // Planner tab
        }
    }
}

// MARK: - Local placeholder (keeps ContentView self-contained)
/// Minimal placeholder for tabs not yet implemented.
private struct PlaceholderScreen: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(spacing: 8) {
            Text(title).font(.title.bold())
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview
#Preview {
    var p = UserProfile()
    p.fullName = "Omkar"
    return ContentView(initialProfile: p)
}
