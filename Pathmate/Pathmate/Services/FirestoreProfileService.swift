//
//  FirestoreProfileService.swift
//  Pathmate
//
//  Created by Omkar Lad on 15/10/2025.
//

import Foundation
import FirebaseFirestore
import SwiftData

/// Syncs the user profile document between Firestore and SwiftData with
/// **last-write-wins** (LWW) conflict resolution on `updatedAt`.
///
/// Firestore path shape: `/users/{uid}`
///
/// Responsibilities:
/// - **start/stop** a snapshot listener for the profile doc
/// - **merge remote → local** when remote is newer
/// - **push local → remote** after local saves
///
/// - Important: `email` typically comes from Auth; this service keeps the SwiftData
///   profile in sync for other fields like full name, study level, intake, city,
///   and university.
/// - SeeAlso: ``AuthService``, ``UserProfileEntity``, ``FirestoreTaskStateService``.
@MainActor
final class FirestoreProfileService: ObservableObject {
    static let shared = FirestoreProfileService()
    private init() {}

    /// Firestore database handle for profile sync.
    private let db = Firestore.firestore()
    /// Live listener for `/users/{uid}` (removed in ``stop()``).
    private var listener: ListenerRegistration?

    /// Resolve the profile document reference.
    /// - Parameter uid: Authenticated user id.
    private func doc(uid: String) -> DocumentReference {
        db.collection("users").document(uid)
    }

    /// Begin listening to the remote profile and merge newer changes into SwiftData.
    ///
    /// - Parameters:
    ///   - uid: Authenticated user id.
    ///   - modelContext: The SwiftData context to read/write.
    func start(uid: String, modelContext: ModelContext) {
        stop() // prevent duplicate listeners
        listener = doc(uid: uid).addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor in
                if error != nil {
                    // print("[FS] profile listen error: \(error)")
                    return
                }
                guard let data = snapshot?.data(), !data.isEmpty else {
                    // No remote doc yet → optionally seed from local if present
                    self?.seedRemoteIfNeeded(uid: uid, modelContext: modelContext)
                    return
                }
                self?.mergeRemoteIntoLocal(uid: uid, data: data, modelContext: modelContext)
            }
        }
    }

    /// Remove the active profile listener (idempotent).
    func stop() {
        listener?.remove(); listener = nil
    }

    /// Push the latest local SwiftData profile to Firestore using `merge: true`.
    ///
    /// Sets `updatedAt` to the current timestamp; adds `createdAt` on first write.
    /// Call this after local edits (e.g., Setup form save).
    /// - Note: Errors are intentionally ignored for A2; add logging for production.
    func pushFromLocal(uid: String, modelContext: ModelContext) async {
        do {
            let fetch = FetchDescriptor<UserProfileEntity>()
            let local = try modelContext.fetch(fetch).first
            guard let p = local else { return }

            var payload: [String: Any] = [
                "fullName": p.fullName,
                "studyLevel": p.studyLevel,
                "intakeMonth": p.intakeMonth,
                "intakeYear": p.intakeYear,
                "fromCountry": p.fromCountry,
                "toCountry": p.toCountry,
                "cityName": p.cityName,
                "universityName": p.universityName,
                "acceptedPolicy": p.acceptedPolicy,
                "updatedAt": Timestamp(date: Date())
            ]
            let d = doc(uid: uid)
            let snap = try await d.getDocument()
            if !(snap.exists) {
                payload["createdAt"] = FieldValue.serverTimestamp()
            }
            try await d.setData(payload, merge: true)
        } catch {
            // print("[FS] pushFromLocal error: \(error)")
        }
    }

    // MARK: - Private helpers
    /// If no remote doc exists yet, push the local profile once (best-effort).
    private func seedRemoteIfNeeded(uid: String, modelContext: ModelContext) {
        do {
            let fetch = FetchDescriptor<UserProfileEntity>()
            if (try modelContext.fetch(fetch).first) != nil {
                Task { await self.pushFromLocal(uid: uid, modelContext: modelContext) }
            }
        } catch {
            // ignore for A2
        }
    }
    
    /// Apply a remote profile payload to SwiftData when the remote `updatedAt` is newer.
    ///
    /// - Parameters:
    ///   - uid: Authenticated user id.
    ///   - data: Firestore fields for the profile.
    ///   - modelContext: The SwiftData context to mutate.
    /// - Important: This is a *newest-wins* merge; local edits should be followed by
    ///   ``pushFromLocal(uid:modelContext:)`` to advance `updatedAt`.
    private func mergeRemoteIntoLocal(uid: String, data: [String: Any], modelContext: ModelContext) {
        // Extract remote updatedAt
        let remoteUpdated = (data["updatedAt"] as? Timestamp)?.dateValue() ?? .distantPast

        // Load local row or create one
        let fetch = FetchDescriptor<UserProfileEntity>()
        let local = (try? modelContext.fetch(fetch).first)
        let localUpdated = local?.updatedAt ?? .distantPast

        // Last‑write‑wins: if remote is newer, hydrate local; otherwise keep local.
        guard remoteUpdated > localUpdated else { return }

        let row: UserProfileEntity
        if let existing = local {
            row = existing
        } else {
            row = UserProfileEntity(
                fullName: "",
                email: "", // email is from Auth; keep empty in SwiftData if you plan to deprecate this column
                studyLevel: "Bachelor",
                intakeMonth: Calendar.current.component(.month, from: .now),
                intakeYear: Calendar.current.component(.year, from: .now),
                fromCountry: "India",
                toCountry: "Australia",
                cityName: "",
                universityName: "",
                acceptedPolicy: false
            )
            modelContext.insert(row)
        }

        // Map fields safely
        row.fullName       = data["fullName"] as? String ?? row.fullName
        row.studyLevel     = data["studyLevel"] as? String ?? row.studyLevel
        row.intakeMonth    = data["intakeMonth"] as? Int ?? row.intakeMonth
        row.intakeYear     = data["intakeYear"] as? Int ?? row.intakeYear
        row.fromCountry    = data["fromCountry"] as? String ?? row.fromCountry
        row.toCountry      = data["toCountry"] as? String ?? row.toCountry
        row.cityName       = data["cityName"] as? String ?? row.cityName
        row.universityName = data["universityName"] as? String ?? row.universityName
        row.acceptedPolicy = data["acceptedPolicy"] as? Bool ?? row.acceptedPolicy
        row.updatedAt      = remoteUpdated

        try? modelContext.save()
    }
}
