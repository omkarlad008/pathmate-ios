//
//  SetupView.swift
//  Pathmate
//
//  Created by Kshitija on 28/8/2025.
//

// MARK: - Imports
// SwiftUI for form, pickers, and navigation.
import SwiftUI
import SwiftData

// MARK: - Local helpers
/// Month–Year formatter used in Setup (e.g., "Oct 2025").
///
/// - Note: Uses a fixed `dateFormat` for the prototype. Prefer
///   `setLocalizedDateFormatFromTemplate("MMMyyyy")` later for localization.
private extension DateFormatter {
    static let setupMonthYear: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f
    }()
}
/// Optional gender selection for personalisation (segmented control).
///
/// Raw values are user-visible strings.
private enum Gender: String, CaseIterable, Identifiable {
    case female = "Female", male = "Male", preferNot = "Other"
    var id: String { rawValue }
}

/// Month–Year value object (no day); converts to `Date` by pinning `day = 1`.
///
/// - Note: Keeps intake selection independent from calendar day.
private struct MonthYear: Equatable {
    var month: Int   // 1...12
    var year:  Int
    /// Converts the month–year to a `Date` (first day of that month).
    var date: Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = 1
        return Calendar.current.date(from: c) ?? .now
    }
    /// Convenience for initialising the picker to the current month–year.
    static var current: MonthYear {
        let c = Calendar.current.dateComponents([.year, .month], from: .now)
        return .init(month: c.month ?? 1, year: c.year ?? 2025)
    }
}
/// Wheel picker for selecting month and year only.
///
/// - Parameters:
///   - value: Two-way binding to the selected month-year.
///   - yearRange: Inclusive range of selectable years.
private struct MonthYearPicker: View {
    @Binding var value: MonthYear
    let yearRange: ClosedRange<Int>
    
    var body: some View {
        HStack {
            Picker("Month", selection: $value.month) {
                ForEach(1...12, id: \.self) { m in
                    Text(DateFormatter().monthSymbols[m-1]).tag(m)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)

            Picker("Year", selection: $value.year) {
                ForEach(yearRange, id: \.self) { y in Text("\(y, format: .number.grouping(.never))") }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
        }
        .labelsHidden()
        .frame(height: 140)
    }
}

// MARK: - Setup View
/// **SetupView (Onboarding)**
///
/// First-run flow that collects minimal profile details to personalize the
/// journey: name, email, study level, intake month–year, and campus.
/// Validates inputs and enables **Start Journey** when all checks pass.
///
/// - SeeAlso: ``UserProfile``, ``StudyLevel``
/// - Important: This prototype keeps data on-device only.
struct SetupView: View {
    /// Two-way binding to the profile being edited.
    @Binding var profile: UserProfile
    /// Callback invoked after saving the intake date/campus when the form is valid.
    var onStart: () -> Void

    // SwiftData model context for local persistence (UserProfileEntity).
    @Environment(\.modelContext) private var modelContext
    
    // Email comes from Auth; we don't let the user edit it here
    @EnvironmentObject private var auth: AuthService
    
    @State private var gender: Gender = .preferNot

    @StateObject private var vm = UniversityPickerViewModel()
    @State private var selectedCity: String = ""
    @State private var selectedInstitutionID: String? = nil

    @State private var intakeMY: MonthYear = .current
    @State private var acceptTerms: Bool = false


    /// Non-empty check for the full name field.
    private var nameValid: Bool {
        !profile.fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    /// Basic email pattern check (case-insensitive, simplified for prototype).
    ///
    /// - Warning: Not a full RFC validator.
    private var emailValid: Bool {
        !auth.email.isEmpty
    }
    private var uniValid: Bool { selectedInstitutionID != nil }
    private var termsValid: Bool { acceptTerms }
    /// Aggregated form validity used to enable the **Start Journey** button.
    private var canStart: Bool { nameValid && emailValid && uniValid && termsValid }
    /// Allows selecting the current year up to two years ahead.
    private var yearRange: ClosedRange<Int> {
        let y = Calendar.current.component(.year, from: .now)
        return y...(y + 2)
    }
    /// Form with sections for About You, Study Plan, and Agreements.
    /// The bottom bar contains the primary action to start the journey.
    var body: some View {
        NavigationStack {
            Form {
                // ABOUT YOU
                Section {
                    TextField("Full name", text: $profile.fullName)
                        .textContentType(.name)
                        .submitLabel(.done)
                    if !nameValid { Text("Name required").foregroundStyle(.red) }

                    // Show email from Auth, read-only
                    TextField("Email", text: .constant(auth.email))
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .disabled(true)
                        .foregroundStyle(.secondary)
                    if !emailValid { Text("Enter a valid email").foregroundStyle(.red) }

                    Picker("Gender", selection: $gender) {
                        ForEach(Gender.allCases) { g in Text(g.rawValue).tag(g) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical,12)
                } header: {
                    Text("About you")
                }

                // STUDY PLAN
                Section {
                    HStack {
                        Label("From country", systemImage: "airplane.departure")
                        Spacer()
                        Text(profile.fromCountry).foregroundStyle(.secondary)
                    }
                    HStack {
                        Label("To country", systemImage: "airplane.arrival")
                        Spacer()
                        Text(profile.toCountry).foregroundStyle(.secondary)
                    }

                    Picker("Study level", selection: $profile.studyLevel) {
                        ForEach(StudyLevel.allCases) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 12)

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Intake (month & year)", systemImage: "calendar")
                            .font(.subheadline.weight(.semibold))
                        MonthYearPicker(value: $intakeMY, yearRange: yearRange)
                        Text("Selected: \(DateFormatter.setupMonthYear.string(from: intakeMY.date))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .listRowInsets(EdgeInsets())
                    .padding(.all, 20)

                    // City → University (dependent pickers)
                    if vm.isLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Fetching cities and universities…")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Picker("City", selection: $selectedCity) {
                            Text("Select a city").tag("")
                            ForEach(vm.cities, id: \.self) { city in
                                Text(city).tag(city)
                            }
                        }
                        .pickerStyle(.navigationLink)

                        Picker("University", selection: $selectedInstitutionID) {
                            let items = vm.institutions(in: selectedCity)
                            ForEach(items) { inst in
                                Text(inst.display_name).tag(Optional(inst.id))
                            }
                        }
                        .pickerStyle(.navigationLink)
                        .disabled(selectedCity.isEmpty)
                    }

                    if let e = vm.error {
                        Text(e).font(.footnote).foregroundStyle(.red)
                    }

                    if !uniValid { Text("Select your university/campus").foregroundStyle(.red) }

                } header: {
                    Text("Study plan")
                } footer: {
                    Text("We use this to personalise your timeline and reminders.")
                }

                // AGREEMENTS
                Section {
                    Toggle("I accept the Terms & Privacy Policy", isOn: $acceptTerms)
                    if !termsValid { Text("You must accept to continue").foregroundStyle(.red) }
                } header: {
                    Text("Agreements")
                }
            }
            .navigationTitle("Welcome • Setup")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .task { await vm.refresh() }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    // Saves intake date and campus into the bound profile, then calls `onStart`.
                    Button {
                        // Save back into your profile
                        profile.intakeDate = intakeMY.date
                        if let id = selectedInstitutionID,
                           let uni = vm.institutions.first(where: { $0.id == id }) {
                            profile.cityCampus = selectedCity.isEmpty
                                ? uni.display_name
                                : "\(uni.display_name) (\(selectedCity))"
                        } else {
                            profile.cityCampus = ""
                        }
                        
                        // --- SwiftData: Upsert a single UserProfileEntity (minimal fields) ---
                        do {
                            // Derive city + university as separate fields for storage
                            let universityName: String = {
                                if let id = selectedInstitutionID,
                                   let uni = vm.institutions.first(where: { $0.id == id }) {
                                    return uni.display_name
                                }
                                return ""
                            }()

                            let cityName: String = selectedCity

                            // Try to load existing (single-user) profile row
                            let fetch = FetchDescriptor<UserProfileEntity>()
                            let existing = try modelContext.fetch(fetch).first

                            if let row = existing {
                                row.fullName       = profile.fullName
                                row.email          = auth.email // mirror from Auth
                                row.studyLevel     = profile.studyLevel.rawValue
                                row.intakeMonth    = intakeMY.month
                                row.intakeYear     = intakeMY.year
                                row.fromCountry    = profile.fromCountry
                                row.toCountry      = profile.toCountry
                                row.cityName       = cityName
                                row.universityName = universityName
                                row.acceptedPolicy = acceptTerms
                                row.updatedAt      = .now
                            } else {
                                let row = UserProfileEntity(
                                    fullName: profile.fullName,
                                    email: auth.email, // mirror from Auth
                                    studyLevel: profile.studyLevel.rawValue,
                                    intakeMonth: intakeMY.month,
                                    intakeYear: intakeMY.year,
                                    fromCountry: profile.fromCountry,
                                    toCountry: profile.toCountry,
                                    cityName: cityName,
                                    universityName: universityName,
                                    acceptedPolicy: acceptTerms
                                )
                                modelContext.insert(row)
                            }

                            try modelContext.save()
                            if let uid = auth.uid {
                                Task { await FirestoreProfileService.shared.pushFromLocal(uid: uid, modelContext: modelContext) }
                            }
                        } catch {}
                        
                        onStart()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.right.circle.fill")
                            Text("Start Journey")
                        }
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canStart)
                    .padding(.vertical, 8)
                    .animation(.easeInOut, value: canStart)

                    Text("You can edit details later from Profile.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 2)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SetupView(profile: .constant(.init()), onStart: {})
}

