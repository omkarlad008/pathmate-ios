//
//  ShakeDetector.swift
//  Pathmate
//
//  Created by Omkar Lad on 17/10/2025.
//

import SwiftUI

extension Notification.Name {
    static let deviceDidShake = Notification.Name("deviceDidShake")
}

struct ShakeDetector: UIViewRepresentable {
    func makeUIView(context: Context) -> ShakeView { ShakeView() }
    func updateUIView(_ uiView: ShakeView, context: Context) {}

    final class ShakeView: UIView {
        override var canBecomeFirstResponder: Bool { true }
        override func didMoveToWindow() {
            super.didMoveToWindow()
            becomeFirstResponder()
        }
        override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
            guard motion == .motionShake else { return }
            NotificationCenter.default.post(name: .deviceDidShake, object: nil)
        }
    }
}
