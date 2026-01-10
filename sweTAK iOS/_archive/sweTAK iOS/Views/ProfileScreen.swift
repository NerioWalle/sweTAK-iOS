import SwiftUI

/// Profile screen for viewing and editing user profile
/// Mirrors Android ProfileScreen functionality
public struct ProfileScreen: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settingsVM = SettingsViewModel.shared

    // Form fields
    @State private var callsign: String = ""
    @State private var nickname: String = ""
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var company: String = ""
    @State private var platoon: String = ""
    @State private var squad: String = ""
    @State private var phone: String = ""
    @State private var email: String = ""
    @State private var role: MilitaryRole = .none

    // Focus management
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case callsign, nickname, firstName, lastName
        case company, platoon, squad, phone, email
    }

    let onSaved: (() -> Void)?

    public init(onSaved: (() -> Void)? = nil) {
        self.onSaved = onSaved
    }

    public var body: some View {
        NavigationStack {
            Form {
                // Identity section
                Section("Identity") {
                    ProfileTextField(
                        title: "Callsign",
                        text: $callsign,
                        placeholder: "e.g., Alpha-1"
                    )
                    .focused($focusedField, equals: .callsign)

                    RolePicker(selection: $role)

                    ProfileTextField(
                        title: "Nickname",
                        text: $nickname,
                        placeholder: "Optional nickname"
                    )
                    .focused($focusedField, equals: .nickname)
                }

                // Personal info section
                Section("Personal Information") {
                    ProfileTextField(
                        title: "First Name",
                        text: $firstName,
                        placeholder: "First name"
                    )
                    .focused($focusedField, equals: .firstName)

                    ProfileTextField(
                        title: "Last Name",
                        text: $lastName,
                        placeholder: "Last name"
                    )
                    .focused($focusedField, equals: .lastName)
                }

                // Unit info section
                Section("Unit Information") {
                    ProfileTextField(
                        title: "Company",
                        text: $company,
                        placeholder: "e.g., 1st Company"
                    )
                    .focused($focusedField, equals: .company)

                    ProfileTextField(
                        title: "Platoon/Troop",
                        text: $platoon,
                        placeholder: "e.g., 2nd Platoon"
                    )
                    .focused($focusedField, equals: .platoon)

                    ProfileTextField(
                        title: "Squad",
                        text: $squad,
                        placeholder: "e.g., Alpha Squad"
                    )
                    .focused($focusedField, equals: .squad)
                }

                // Contact info section
                Section("Contact Information") {
                    ProfileTextField(
                        title: "Mobile",
                        text: $phone,
                        placeholder: "Phone number",
                        keyboardType: .phonePad
                    )
                    .focused($focusedField, equals: .phone)

                    ProfileTextField(
                        title: "Email",
                        text: $email,
                        placeholder: "email@example.com",
                        keyboardType: .emailAddress
                    )
                    .focused($focusedField, equals: .email)
                }

                // Device info section
                Section("Device") {
                    HStack {
                        Text("Device ID")
                        Spacer()
                        Text(settingsVM.deviceId.prefix(8) + "...")
                            .foregroundColor(.secondary)
                            .font(.system(.body, design: .monospaced))
                    }
                }
            }
            .navigationTitle("My Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveProfile()
                    }
                    .fontWeight(.semibold)
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                }
            }
            .onAppear {
                loadProfile()
            }
        }
    }

    // MARK: - Actions

    private func loadProfile() {
        let profile = settingsVM.profile
        callsign = profile.callsign
        nickname = profile.nickname
        firstName = profile.firstName
        lastName = profile.lastName
        company = profile.company
        platoon = profile.platoon
        squad = profile.squad
        phone = profile.phone
        email = profile.email
        role = profile.role
    }

    private func saveProfile() {
        let newProfile = LocalProfile(
            callsign: callsign.trimmingCharacters(in: .whitespacesAndNewlines),
            nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines),
            firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
            lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines),
            company: company.trimmingCharacters(in: .whitespacesAndNewlines),
            platoon: platoon.trimmingCharacters(in: .whitespacesAndNewlines),
            squad: squad.trimmingCharacters(in: .whitespacesAndNewlines),
            phone: phone.trimmingCharacters(in: .whitespacesAndNewlines),
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            role: role
        )

        settingsVM.updateProfile(newProfile)
        onSaved?()
        dismiss()
    }
}

// MARK: - Profile Text Field

private struct ProfileTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        HStack {
            Text(title)
                .frame(width: 100, alignment: .leading)
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .textContentType(contentType)
                .autocapitalization(autocapitalization)
        }
    }

    private var contentType: UITextContentType? {
        switch keyboardType {
        case .phonePad: return .telephoneNumber
        case .emailAddress: return .emailAddress
        default: return nil
        }
    }

    private var autocapitalization: UITextAutocapitalizationType {
        switch keyboardType {
        case .emailAddress: return .none
        default: return .words
        }
    }
}

// MARK: - Role Picker

private struct RolePicker: View {
    @Binding var selection: MilitaryRole

    var body: some View {
        Picker("Role", selection: $selection) {
            ForEach(MilitaryRole.allCases.filter { $0 != .none }, id: \.self) { role in
                Text(role.displayName)
                    .tag(role)
            }
        }
    }
}

// MARK: - Preview

#Preview("Profile Screen") {
    ProfileScreen()
}
