//
//  AuthService.swift
//  Pathmate
//
//  Created by Omkar Lad on 15/10/2025.
//

import Foundation
import FirebaseAuth

/// Thin `@MainActor` wrapper around Firebase Authentication that exposes the
/// current user, loading state, and auth operations for the UI.
///
/// Listens to `Auth.auth().addStateDidChangeListener` and updates published
/// properties on the main actor so SwiftUI can react (e.g., splash/guard screens).
///
/// - Important: `AuthService` does **not** start/stop Firestore sync on its own.
///   Call into ``FirestoreProfileService`` / ``FirestoreTaskStateService`` based on
///   `isAuthenticated`.
/// - SeeAlso: ``FirestoreProfileService``, ``FirestoreTaskStateService``.
@MainActor
final class AuthService: ObservableObject {
    /// The current Firebase `User`. `nil` while signed out or before initial load.
    @Published private(set) var user: User?
    /// `true` during the initial auth listener handshake or while a sign-in/up request is in flight.
    @Published private(set) var isLoading: Bool = true
    /// Latest human-readable error produced by a sign-in/up failure (for transient UI display).
    @Published var errorMessage: String?
    /// Internal Firebase auth state listener handle (removed on `deinit`).
    private var listener: AuthStateDidChangeListenerHandle?

    /// Sets up the auth state listener and marks `isLoading = false` once the first
    /// callback arrives (regardless of signed-in/out outcome).
    init() {
        listener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.user = user
                self?.isLoading = false
            }
        }
    }

    /// Removes the auth state change listener to prevent leaks.
    deinit { if let l = listener { Auth.auth().removeStateDidChangeListener(l) } }

    /// Convenience flag for view gating.
    /// - Returns: `true` when a user session exists.
    var isAuthenticated: Bool { user != nil }
    /// Convenience accessor for the current user id.
    var uid: String? { user?.uid }
    /// Convenience accessor for the current user email (empty string if unavailable).
    var email: String { user?.email ?? "" }

    /// Sign in with email/password using Firebase Auth.
    ///
    /// Updates `isLoading` during the request and populates `errorMessage` when
    /// throwing.
    /// - Parameters:
    ///   - email: The user’s email.
    ///   - password: The user’s password.
    /// - Throws: A Firebase Auth error if the sign-in fails.
    func signIn(email: String, password: String) async throws {
        isLoading = true
        do {
            _ = try await Auth.auth().signIn(withEmail: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            throw error
        }
    }

    /// Create a new account with email/password using Firebase Auth.
    ///
    /// Behavior mirrors ``signIn(email:password:)`` for `isLoading`/`errorMessage`.
    /// - Throws: A Firebase Auth error if sign-up fails.
    func signUp(email: String, password: String) async throws {
        isLoading = true
        do {
            _ = try await Auth.auth().createUser(withEmail: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            throw error
        }
    }

    /// Sign out the current user.
    /// - Important: Call `stop()` on your Firestore sync services and reset any
    ///   in-memory stores that depend on the authenticated user.
    func signOut() throws {
        try Auth.auth().signOut()
    }
}
