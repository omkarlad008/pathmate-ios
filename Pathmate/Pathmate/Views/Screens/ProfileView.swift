//
//  ProfileView.swift
//  Pathmate
//
//  Created by Omkar Lad on 27/8/2025.
//

// MARK: - Imports
import SwiftUI
import SwiftData
import Foundation

/// **ProfileView**
///
/// SwiftData-backed profile viewer/editor.
/// - Email is read-only.
/// - Route is hidden (non-editable).
/// - Study level restricted to **Bachelor** / **Master**.
/// - Campus uses the SAME City → University pickers as Setup (`UniversityPickerViewModel`).
///
/// - SeeAlso: ``SetupView``, ``UserProfileEntity``, ``UniversityPickerViewModel``
struct ProfileView: View {

    // MARK: - SwiftData
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfileEntity]
    @EnvironmentObject private var auth: AuthService

    // MARK: - Editing state
    @State private var isEditing = false

    // Local editable copies (hydrate from SwiftData on appear / when Edit tapped)
    @State private var fullName: String = ""
    @State private var email: String = ""                      // read-only

    @State private var studyLevel: String = "Bachelor"         // "Bachelor" | "Master"
    @State private var intakeMonth: Int = Calendar.current.component(.month, from: Date()) // 1...12
    @State private var intakeYear:  Int = Calendar.current.component(.year,  from: Date())

    // Campus (stored values)
    @State private var cityName: String = ""
    @State private var universityName: String = ""

    // Editing-only selectors (shared with Setup flow)
    @StateObject private var uniVM = UniversityPickerViewModel()
    @State private var selectedCity: String = ""
    @State private var selectedInstitutionID: String? = nil
    
    // Sign-out UI state
    @State private var showSignOutConfirm = false
    @State private var isSigningOut = false

    // MARK: - UI constants
    private let levels = ["Bachelor", "Master"]
    private var monthNames: [String] { Calendar.current.monthSymbols }
    private var yearOptions: [Int] {
        let base = Calendar.current.component(.year, from: Date())
        return Array(base...(base + 5))
    }

    // MARK: - Derived
    private var profile: UserProfileEntity? { profiles.first }

    var body: some View {
        NavigationStack {
            Form {
                // PROFILE
                Section(header: Text("Profile").font(.subheadline)) {
                    TextField("Full name", text: $fullName)
                        .textContentType(.name)
                        .autocorrectionDisabled()
                        .disabled(!isEditing)

                    // Email (read-only)
                    HStack {
                        Text("Email")
                        Spacer()
                        Text(auth.email)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .accessibilityElement(children: .combine)
                }

                // STUDY
                Section(header: Text("Study").font(.subheadline)) {
                    Picker("Level", selection: $studyLevel) {
                        ForEach(levels, id: \.self) { Text($0) }
                    }
                    .disabled(!isEditing)

                    // Intake month (top) then year (below) — stacked
                    Picker("Intake month", selection: $intakeMonth) {
                        ForEach(1...12, id: \.self) { m in
                            Text(monthNames[m - 1]).tag(m)
                        }
                    }
                    .disabled(!isEditing)

                    Picker("Intake year", selection: $intakeYear) {
                        ForEach(yearOptions, id: \.self) { y in
                            Text("\(y)").tag(y)
                        }
                    }
                    .disabled(!isEditing)
                }

                // CAMPUS — City above University (view + edit), uni disabled until city chosen
                Section(header: Text("Campus").font(.subheadline)) {
                    if isEditing {
                        // City first
                        Picker("City", selection: $selectedCity) {
                            Text("Select a city").tag("")
                            ForEach(uniVM.cities, id: \.self) { city in
                                Text(city).tag(city)
                            }
                        }
                        .pickerStyle(.navigationLink)

                        // University second; disabled until city picked
                        Picker("University", selection: $selectedInstitutionID) {
                            let items = uniVM.institutions(in: selectedCity)
                            ForEach(items) { inst in
                                Text(inst.display_name).tag(Optional(inst.id))
                            }
                        }
                        .pickerStyle(.navigationLink)
                        .disabled(selectedCity.isEmpty)

                        if let e = uniVM.error {
                            Text(e).font(.footnote).foregroundStyle(.red)
                        }
                    } else {
                        // Read-only labels (City above University)
                        HStack {
                            Text("City")
                            Spacer()
                            Text(cityName.isEmpty ? "—" : cityName)
                                .foregroundStyle(cityName.isEmpty ? .tertiary : .secondary)
                        }
                        HStack {
                            Text("University")
                            Spacer()
                            Text(universityName.isEmpty ? "—" : universityName)
                                .foregroundStyle(universityName.isEmpty ? .tertiary : .secondary)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
                
                // ACCOUNT
                Section {
                    Button {
                        showSignOutConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign out")
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .tint(.red)
                    .disabled(isSigningOut)
                } header: {
                    Text("Account").font(.subheadline)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if isEditing {
                        Button("Save") { saveEdits() }
                            .disabled(!canSave)
                    } else {
                        Button("Edit") { beginEdit() }
                    }
                }
                if isEditing {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { cancelEdit() }
                    }
                }
            }
            // Keep local fields in sync with persisted data
            .onAppear { hydrateFromStoreIfNeeded() }
            // Clear university selection when city changes (Setup behavior)
            .onChange(of: selectedCity) { _, _ in selectedInstitutionID = nil }
            .alert("Sign out?", isPresented: $showSignOutConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Sign out", role: .destructive) { performSignOut() }
            } message: {
                Text("You’ll return to the sign-in screen. Local data will be cleared on this device.")
            }
        }
    }

    // MARK: - Actions

    /// Enter edit mode and prime the pickers with current stored values.
    private func beginEdit() {
        hydrateFromStoreIfNeeded()
        // Prime the city/university pickers from current stored values
        selectedCity = cityName
        if !universityName.isEmpty {
            let items = uniVM.institutions(in: selectedCity)
            selectedInstitutionID = items.first(where: { $0.display_name == universityName })?.id
        } else {
            selectedInstitutionID = nil
        }
        // Fetch (or refresh) the AU institutions list only when needed
        Task { await uniVM.refresh() }
        withAnimation { isEditing = true }
    }

    /// Cancel editing and restore UI from the store.
    private func cancelEdit() {
        hydrateFromStoreIfNeeded()
        withAnimation { isEditing = false }
    }

    /// Persist local edits back to SwiftData.
    private func saveEdits() {
        guard let p = profile else { return }

        // Resolve final University/City from the selectors
        var newUniversity = universityName
        var newCity       = cityName

        if let id = selectedInstitutionID,
           let uni = uniVM.institutions.first(where: { $0.id == id }) {
            newUniversity = uni.display_name
            newCity = selectedCity.isEmpty ? (uni.geo?.city ?? cityName) : selectedCity
        } else {
            // Allow updating city independently (as per Setup behavior)
            newCity = selectedCity.isEmpty ? cityName : selectedCity
        }

        p.fullName        = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        // email is read-only
        p.studyLevel      = levels.contains(studyLevel) ? studyLevel : "Bachelor"
        p.intakeMonth     = (1...12).contains(intakeMonth) ? intakeMonth : Calendar.current.component(.month, from: .now)
        p.intakeYear      = intakeYear
        p.cityName        = newCity
        p.universityName  = newUniversity
        p.updatedAt       = Date()

        try? modelContext.save()
        withAnimation { isEditing = false }
        if let uid = auth.uid {
            Task { await FirestoreProfileService.shared.pushFromLocal(uid: uid, modelContext: modelContext) }
        }
    }

    /// Hydrate the UI from SwiftData when not editing.
    private func hydrateFromStoreIfNeeded() {
        guard !isEditing, let p = profile else { return }
        fullName        = p.fullName
        email           = auth.email
        studyLevel      = levels.contains(p.studyLevel) ? p.studyLevel : "Bachelor"
        intakeMonth     = (1...12).contains(p.intakeMonth) ? p.intakeMonth : intakeMonth
        intakeYear      = p.intakeYear > 0 ? p.intakeYear : intakeYear
        cityName        = p.cityName
        universityName  = p.universityName
    }

    // MARK: - Validation
    private var canSave: Bool {
        !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Sign out & local wipe
    private func performSignOut() {
        guard !isSigningOut else { return }
            isSigningOut = true
            // Stop any listeners first (AppRootView will also stop on uid change)
            FirestoreProfileService.shared.stop()
            FirestoreTaskStateService.shared.stop()
            // Wipe local SwiftData so a new user doesn't see old data
            wipeLocalStore()
            do {
                try auth.signOut()
            } catch {
                // Optional: surface error via a toast
            }
            isSigningOut = false
        }
    
    /// Deletes all local entities for a clean state after sign out.
    private func wipeLocalStore() {
        do {
            // Remove profile(s)
            let pFetch = FetchDescriptor<UserProfileEntity>()
            let pAll = try modelContext.fetch(pFetch)
            pAll.forEach { modelContext.delete($0) }
            // Remove task states (planner/done)
            let tFetch = FetchDescriptor<TaskStateEntity>()
            let tAll = try modelContext.fetch(tFetch)
            tAll.forEach { modelContext.delete($0) }
            try modelContext.save()
            } catch {
                
            }
        }
}
