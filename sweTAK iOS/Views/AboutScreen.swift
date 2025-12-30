import SwiftUI

/// About screen showing app information, developer contact, and disclaimer.
public struct AboutScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage("swetak_dont_show_about_at_startup") private var dontShowAtStartup = false

    let showStartupCheckbox: Bool

    public init(showStartupCheckbox: Bool = true) {
        self.showStartupCheckbox = showStartupCheckbox
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    headerSection

                    // About section
                    sectionView(title: "About") {
                        Text("sweTAK is a tactical awareness application designed for team coordination and situational awareness in field operations.")
                    }

                    // Developer section
                    sectionView(title: "Developer") {
                        VStack(alignment: .leading, spacing: 8) {
                            labeledText(label: "Organisation:", value: "Nerio Defense AB")
                            labeledText(label: "Developer:", value: "Michael Wallenius")
                            labeledLink(label: "Email:", url: "mailto:michael.wallenius@neriodefense.se", text: "michael.wallenius@neriodefense.se")
                            labeledLink(label: "Website:", url: "https://neriodefense.se", text: "neriodefense.se")
                        }
                    }

                    // Support section
                    sectionView(title: "Support") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("For bug reports and feature requests, please contact us via our Customer Service portal.")

                            Link(destination: URL(string: "https://neriodefense.atlassian.net/servicedesk/customer/portal/1/group/3")!) {
                                HStack {
                                    Image(systemName: "link")
                                    Text("Customer Service Portal")
                                }
                                .foregroundColor(.blue)
                            }
                        }
                    }

                    // Disclaimer
                    disclaimerSection

                    // Copyright
                    copyrightSection

                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("About sweTAK")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomSection
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "map.fill")
                    .font(.largeTitle)
                    .foregroundColor(.blue)

                Text("sweTAK")
                    .font(.largeTitle)
                    .fontWeight(.bold)
            }

            Text("Version \(appVersion) (\(buildDate))")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Section View

    private func sectionView<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)

            content()
        }
    }

    // MARK: - Labeled Text

    private func labeledText(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .fontWeight(.semibold)
            Text(value)
        }
    }

    // MARK: - Labeled Link

    private func labeledLink(label: String, url: String, text: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .fontWeight(.semibold)
            Link(text, destination: URL(string: url)!)
                .foregroundColor(.blue)
        }
    }

    // MARK: - Disclaimer Section

    private var disclaimerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Disclaimer")
                    .fontWeight(.semibold)
            }

            Text("This software is provided for demonstration and training purposes. The developers assume no responsibility for operational use. Always verify critical information through official channels.")
                .font(.callout)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Copyright Section

    private var copyrightSection: some View {
        Text("© 2024 Nerio Defense AB. All rights reserved. Nerio Defense is a registered trademark.")
            .font(.caption)
            .foregroundColor(.secondary)
    }

    // MARK: - Bottom Section

    private var bottomSection: some View {
        VStack(spacing: 12) {
            if showStartupCheckbox {
                Toggle(isOn: $dontShowAtStartup) {
                    Text("Don't show this at startup")
                        .font(.subheadline)
                }
                .toggleStyle(.checkbox)
            }

            Button {
                dismiss()
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.bar)
    }

    // MARK: - App Info

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildDate: String {
        "December 2024"
    }
}

// MARK: - Checkbox Toggle Style

private struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .foregroundColor(configuration.isOn ? .blue : .secondary)
                configuration.label
            }
        }
        .buttonStyle(.plain)
    }
}

extension ToggleStyle where Self == CheckboxToggleStyle {
    static var checkbox: CheckboxToggleStyle { CheckboxToggleStyle() }
}

// MARK: - Helper for checking startup preference

public struct AboutScreenHelper {
    private static let key = "swetak_dont_show_about_at_startup"

    public static var shouldShowAtStartup: Bool {
        !UserDefaults.standard.bool(forKey: key)
    }

    public static func setDontShowAtStartup(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: key)
    }
}

// MARK: - Preview

#Preview("About Screen") {
    AboutScreen()
}

#Preview("About Screen (No Checkbox)") {
    AboutScreen(showStartupCheckbox: false)
}
