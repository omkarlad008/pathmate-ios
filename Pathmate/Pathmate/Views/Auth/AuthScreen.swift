//
//  AuthScreen.swift
//  Pathmate
//
//  Created by Omkar Lad on 15/10/2025.
//

import SwiftUI
/// Email/password sign-in & sign-up screen backed by ``AuthService``.
///
/// Shows basic errors from `auth.errorMessage` and a busy state during requests.
struct AuthScreen: View {
    @EnvironmentObject private var auth: AuthService

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var mode: Mode = .signIn
    @State private var isBusy = false
    /// Toggles between **Sign in** and **Create account** flows.
    enum Mode: String, CaseIterable { case signIn = "Sign in", signUp = "Create account" }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Pathmate").font(.largeTitle).bold()
                Text("Welcome! Please \(mode == .signIn ? "sign in" : "create an account") to continue.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                Group {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)

                if let err = auth.errorMessage, !err.isEmpty {
                    Text(err).foregroundStyle(.red).font(.footnote).padding(.horizontal)
                }

                Button(action: submit) {
                    HStack {
                        if isBusy { ProgressView() }
                        Text(mode == .signIn ? "Sign in" : "Create account").bold()
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isBusy || email.isEmpty || password.count < 6)
                .padding(.horizontal)

                Spacer()
                Text("We’ll use your email only for login. You can edit your profile details later.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Text("v1").foregroundStyle(.secondary) } }
        }
    }
    /// Submits the selected auth flow.
    ///
    /// Calls ``AuthService/signIn(email:password:)`` or
    /// ``AuthService/signUp(email:password:)`` and lets `auth.errorMessage` surface errors.
    private func submit() {
        Task { @MainActor in
            isBusy = true
            defer { isBusy = false }
            do {
                switch mode {
                case .signIn: try await auth.signIn(email: email, password: password)
                case .signUp: try await auth.signUp(email: email, password: password)
                }
            } catch { /* error shown via auth.errorMessage */ }
        }
    }
}
