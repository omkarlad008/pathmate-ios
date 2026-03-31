//
//  FirestoreTaskStateService.swift
//  Pathmate
//
//  Created by Omkar Lad on 15/10/2025.
//

import Foundation
import FirebaseFirestore
import SwiftData

/// Bi-directional sync for individual task states between Firestore and SwiftData,
/// using **last-write-wins** on `updatedAt`.
///
/// Firestore path shape: `/users/{uid}/taskStates/{taskKey}`
///
/// Each document mirrors essential fields of ``TaskStateEntity``: `taskKey`,
/// `stageRaw`, optional `dueDate`, `isDone`, optional `doneAt`, and timestamps.
///
/// - SeeAlso: ``TaskStateEntity``, ``FirestoreProfileService``, ``AuthService``.
@MainActor
final class FirestoreTaskStateService: ObservableObject {
    static let shared = FirestoreTaskStateService()
    private init() {}

    /// Firestore database handle for task state sync.
    private let db = Firestore.firestore()
    /// Collection listener for `/taskStates` (removed in ``stop()``).
    private var listener: ListenerRegistration?
    /// Resolve the collection for task state documents under the given user.
    private func col(uid: String) -> CollectionReference {
        db.collection("users").document(uid).collection("taskStates")
    }

    /// Start a live listener on `/taskStates` and merge changes into SwiftData.
    ///
    /// - Parameters:
    ///   - uid: Authenticated user id.
    ///   - modelContext: SwiftData context to update.
    func start(uid: String, modelContext: ModelContext) {
        stop()
        listener = col(uid: uid).addSnapshotListener { snapshot, error in
            Task { @MainActor in
                guard let snapshot = snapshot, error == nil else { return }
                for change in snapshot.documentChanges {
                    let data = change.document.data()
                    let key  = change.document.documentID
                    self.mergeRemoteIntoLocal(taskKey: key, data: data, modelContext: modelContext)
                }
            }
        }
    }
    /// Remove the active task state listener (idempotent).
    func stop() { listener?.remove(); listener = nil }

    /// Push a single local task state to Firestore (merge-write).
    ///
    /// Sets `updatedAt` to now and `createdAt` on first write. `dueDate` / `doneAt` are
    /// written as Firestore `Timestamp` or `nil` to clear.
    /// - Parameters:
    ///   - uid: Authenticated user id.
    ///   - taskKey: Unique checklist task key (matches ``TaskStateEntity/taskKey``).
    ///   - modelContext: SwiftData context used to load the local row.
    func push(uid: String, taskKey: String, modelContext: ModelContext) async {
        do {
            let fetch = FetchDescriptor<TaskStateEntity>(
                predicate: #Predicate { $0.taskKey == taskKey }
            )
            guard let s = try modelContext.fetch(fetch).first else { return }

            var payload: [String: Any] = [
                "taskKey": s.taskKey,
                "stageRaw": s.stageRaw,
                "isDone": s.isDone,
                "updatedAt": Timestamp(date: Date())
            ]
            payload["dueDate"] = s.dueDate.map(Timestamp.init) ?? NSNull()
            payload["doneAt"]  = s.doneAt.map(Timestamp.init) ?? NSNull()

            let dref = col(uid: uid).document(s.taskKey)
            let snap = try await dref.getDocument()
            if !(snap.exists) { payload["createdAt"] = FieldValue.serverTimestamp() }
            try await dref.setData(payload, merge: true)
        } catch {
            // print("[FS] push task error: \(error)")
        }
    }

    /// Best-effort initial upload of all local task states (one document per task).
    /// - Note: Intended for first-time sync; subsequent updates should call ``push(uid:taskKey:modelContext:)``.
    func pushAll(uid: String, modelContext: ModelContext) async {
        do {
            let fetch = FetchDescriptor<TaskStateEntity>()
            for s in try modelContext.fetch(fetch) {
                await push(uid: uid, taskKey: s.taskKey, modelContext: modelContext)
            }
        } catch { }
    }

    // MARK: - Merge remote → local (LWW)
    /// Merge a remote task state into SwiftData if the remote `updatedAt` is newer.
    ///
    /// Creates a placeholder row if it does not yet exist locally (with conservative
    /// defaults), then applies fields and saves the context.
    /// - Parameters:
    ///   - taskKey: The document id / task key.
    ///   - data: Firestore field map for the task state.
    ///   - modelContext: SwiftData context to mutate.
    /// - Important: This is a *newest-wins* merge. After local edits (e.g., swipe on
    ///   Checklist, Planner toggle, widget intent) call ``push(uid:taskKey:modelContext:)``
    ///   to advance `updatedAt` on the remote.
    private func mergeRemoteIntoLocal(taskKey: String, data: [String: Any], modelContext: ModelContext) {
        let remoteUpdated = (data["updatedAt"] as? Timestamp)?.dateValue() ?? .distantPast

        let fetch = FetchDescriptor<TaskStateEntity>(predicate: #Predicate { $0.taskKey == taskKey })
        var local = try? modelContext.fetch(fetch).first
        if local == nil {
            // Adjust initializer to match your model if needed
            let newRow = TaskStateEntity(
                taskKey: taskKey,
                stageRaw: (data["stageRaw"] as? String) ?? "",
                dueDate: nil,
                isDone: false,
                doneAt: nil
            )
            newRow.updatedAt = .distantPast
            modelContext.insert(newRow)
            local = newRow
        }
        guard let row = local else { return }
        guard remoteUpdated > row.updatedAt else { return } // keep newer local

        row.stageRaw = (data["stageRaw"] as? String) ?? row.stageRaw
        if let due = data["dueDate"] as? Timestamp { row.dueDate = due.dateValue() } else { row.dueDate = nil }
        row.isDone = (data["isDone"] as? Bool) ?? row.isDone
        if let doneTs = data["doneAt"] as? Timestamp { row.doneAt = doneTs.dateValue() } else { row.doneAt = nil }
        row.updatedAt = remoteUpdated

        try? modelContext.save()
    }
}
