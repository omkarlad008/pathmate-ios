//
//  AppGroup.swift
//  Pathmate
//
//  Created by Omkar Lad on 15/10/2025.
//

/// App Group container shared by the app and the widget.
///
/// Used for:
/// - `UserDefaults(suiteName:)` to pass small snapshots, and
/// - the shared container URL to read/write `widget_snapshot.json`.
///
/// - SeeAlso: ``WidgetBridge``
enum AppGroup {
    /// The App Group identifier configured in both targets’ entitlements.
    static let id = "group.edu.rmit.ipse.pathmate"
}
/// WidgetKit kind identifiers used when reloading timelines.
///
/// - Important: Must match the `kind` declared in the widget target.
enum WidgetKind {
    /// The main widget’s `kind` string for `WidgetCenter.reloadTimelines(ofKind:)`.
    static let pathmate = "PathmateWidget"
}
