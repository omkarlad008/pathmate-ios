# Architecture

SwiftUI app with **SwiftData** + **Firebase** (Auth/Firestore) and an **App Group** bridge for the widget.  
**Requirements:** Xcode 16, iOS 17+.

## App Flow
1. ``PathmateApp`` launches (Firebase via ``AppDelegate``).
2. ``AuthGate`` routes:
   - loading → spinner
   - signed in → main tabs
   - signed out → ``AuthScreen``
3. On first run: ``WelcomeView`` → ``SetupView`` → tabs (Home, Journey, Planner).

## Screens
- ``HomeView`` — progress + “Today’s plan”.
- ``JourneyView`` → ``ChecklistView`` → ``TaskDetailView`` (Checklist supports swipe **done/undone**).
- Planner — Scheduled / Completed.

## Data & State
- **SwiftData**: ``UserProfileEntity``, ``TaskStateEntity``.
- **Sync (LWW on `updatedAt`)**: ``FirestoreProfileService`` (profile), ``FirestoreTaskStateService`` (task states).
- **Local progress**: TaskProgressStore (done IDs), PlannerStore (schedule/overdue).
- **Static content**: TaskRepository.

## Widget Path
The app computes a snapshot (WidgetSnapshot) and stores it via an App Group bridge; the widget reads and renders it.  
Interactions from the widget (mark done / reschedule) update SwiftData and patch the snapshot.
