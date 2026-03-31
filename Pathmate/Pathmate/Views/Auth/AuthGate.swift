//
//  AuthGate.swift
//  Pathmate
//
//  Created by Omkar Lad on 15/10/2025.
//

import SwiftUI
/// Routes the user based on authentication state:
/// - shows a spinner while auth loads,
/// - shows `content()` when signed in,
/// - shows ``AuthScreen`` when signed out.
///
/// Inject ``AuthService`` as an `@EnvironmentObject`.
struct AuthGate<Content: View>: View {
    /// Authentication state source for gating.
    @EnvironmentObject private var auth: AuthService
    /// Protected content rendered when the user is authenticated.
    let content: () -> Content

    var body: some View {
        Group {
            if auth.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading…").foregroundStyle(.secondary)
                }
            } else if auth.isAuthenticated {
                content()
            } else {
                AuthScreen()
            }
        }
        .animation(.default, value: auth.isLoading)
        .animation(.default, value: auth.isAuthenticated)
    }
}
