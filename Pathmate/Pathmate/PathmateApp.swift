//
//  PathmateApp.swift
//  Pathmate
//
//  Created by Omkar Lad on 27/8/2025.
//

import SwiftUI
import SwiftData
import FirebaseCore
import Foundation

/// App launch delegate that configures third-party services.
///
/// Currently initializes Firebase in `application(_:didFinishLaunchingWithOptions:)`.
final class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()

    return true
  }
}

/// App entry point.
///
/// Provides:
/// - Firebase setup via ``AppDelegate``
/// - Global ``AuthService`` as an environment object
/// - SwiftData model container for ``UserProfileEntity`` and ``TaskStateEntity``
/// - Deep-link handling for `pathmate://task/<taskID>` to route from the widget
@main
struct PathmateApp: App {
    /// Hooks the UIKit app delegate to run Firebase configuration.
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    /// Global authentication state used for gating the UI.
    @StateObject private var auth = AuthService()
    
    var body: some Scene {
        WindowGroup {
            // Gate the rest of your app behind Auth
            AuthGate {
                AppRootView()
                    .modelContainer(for: [
                        UserProfileEntity.self,
                        TaskStateEntity.self
                ])
            }
            .environmentObject(auth)
            
            // Handle widget deep links: pathmate://task/<taskID>
            .onOpenURL { url in
                guard url.scheme == "pathmate", url.host == "task" else { return }
                NotificationCenter.default.post(
                    name: .openTaskFromWidget,
                    object: nil,
                    userInfo: ["id": url.lastPathComponent]
                )
            }
        }
    }
}

// Global notification used to route from widget -> Task Detail
extension Notification.Name {
    /// Posted when opening a task via the widget deep link.
    ///
    /// - Note: `userInfo["id"]` contains the task key (`String`).
    static let openTaskFromWidget = Notification.Name("openTaskFromWidget")
}
