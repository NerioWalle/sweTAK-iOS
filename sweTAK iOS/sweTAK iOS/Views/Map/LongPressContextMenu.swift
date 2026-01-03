import SwiftUI
import CoreLocation

// MARK: - Long Press Menu Level

/// Navigation level for long-press context menu
public enum LongPressMenuLevel: String {
    case root = "ROOT"
    case pin = "PIN"
    case form = "FORM"
}

// MARK: - Long Press Form Type

/// Types of forms that can be triggered from a long-press on the map
public enum LongPressFormType: String, CaseIterable {
    case sevenS = "FORM_7S"
    case ifs = "FORM_IFS"

    public var displayName: String {
        switch self {
        case .sevenS: return "7S (Contact Report)"
        case .ifs: return "IFS (Indirect Fire)"
        }
    }

    public var icon: String {
        switch self {
        case .sevenS: return "doc.text"
        case .ifs: return "scope"
        }
    }
}

// MARK: - Long Press Context Menu

/// Hierarchical long-press menu for map interactions
/// Lets user choose between Pin, Form, Photo, or Copy Coordinates
public struct LongPressContextMenu: View {
    @Binding var isPresented: Bool
    let coordinate: CLLocationCoordinate2D
    let coordMode: CoordMode

    let onPinChosen: (NatoType) -> Void
    let onFormChosen: (LongPressFormType) -> Void
    let onPhotoChosen: () -> Void
    let onCopyCoordinates: () -> Void

    @State private var menuLevel: LongPressMenuLevel = .root

    public init(
        isPresented: Binding<Bool>,
        coordinate: CLLocationCoordinate2D,
        coordMode: CoordMode = .latLon,
        onPinChosen: @escaping (NatoType) -> Void,
        onFormChosen: @escaping (LongPressFormType) -> Void,
        onPhotoChosen: @escaping () -> Void,
        onCopyCoordinates: @escaping () -> Void
    ) {
        self._isPresented = isPresented
        self.coordinate = coordinate
        self.coordMode = coordMode
        self.onPinChosen = onPinChosen
        self.onFormChosen = onFormChosen
        self.onPhotoChosen = onPhotoChosen
        self.onCopyCoordinates = onCopyCoordinates
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header with coordinates
            VStack(spacing: 4) {
                Text(levelTitle)
                    .font(.headline)

                Text(formattedCoordinate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(.systemGray6))

            Divider()

            // Menu content
            ScrollView {
                VStack(spacing: 0) {
                    switch menuLevel {
                    case .root:
                        rootMenu
                    case .pin:
                        pinMenu
                    case .form:
                        formMenu
                    }
                }
            }
            .frame(maxHeight: 300)

            Divider()

            // Cancel button
            Button(role: .cancel) {
                dismiss()
            } label: {
                Text("Cancel")
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 10)
        .padding()
    }

    // MARK: - Root Menu

    @ViewBuilder
    private var rootMenu: some View {
        MenuRow(icon: "flag.fill", title: "Pin", color: .blue) {
            menuLevel = .pin
        }

        MenuRow(icon: "doc.text.fill", title: "Form", color: .orange) {
            menuLevel = .form
        }

        MenuRow(icon: "camera.fill", title: "Photo", color: .green) {
            onPhotoChosen()
            dismiss()
        }

        MenuRow(icon: "doc.on.doc", title: "Copy Coordinates", color: .purple) {
            onCopyCoordinates()
            dismiss()
        }
    }

    // MARK: - Pin Menu

    @ViewBuilder
    private var pinMenu: some View {
        // Back button
        MenuRow(icon: "chevron.left", title: "Back", color: .secondary) {
            menuLevel = .root
        }

        Divider()
            .padding(.horizontal)

        // Pin types
        ForEach(availablePinTypes, id: \.self) { pinType in
            MenuRow(
                icon: pinType.sfSymbol,
                title: pinType.label,
                color: .blue
            ) {
                onPinChosen(pinType)
                dismiss()
            }
        }
    }

    // MARK: - Form Menu

    @ViewBuilder
    private var formMenu: some View {
        // Back button
        MenuRow(icon: "chevron.left", title: "Back", color: .secondary) {
            menuLevel = .root
        }

        Divider()
            .padding(.horizontal)

        // Form types
        ForEach(LongPressFormType.allCases, id: \.self) { formType in
            MenuRow(
                icon: formType.icon,
                title: formType.displayName,
                color: .orange
            ) {
                onFormChosen(formType)
                dismiss()
            }
        }
    }

    // MARK: - Helpers

    private var availablePinTypes: [NatoType] {
        [.infantry, .intelligence, .surveillance, .artillery, .marine, .droneObserved, .op]
    }

    private var levelTitle: String {
        switch menuLevel {
        case .root: return "Add at Location"
        case .pin: return "Choose Pin Type"
        case .form: return "Choose Form"
        }
    }

    private var formattedCoordinate: String {
        switch coordMode {
        case .mgrs:
            // In real app, convert to MGRS
            return String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude)
        case .latLon:
            return String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude)
        }
    }

    private func dismiss() {
        menuLevel = .root
        isPresented = false
    }
}

// MARK: - Menu Row

private struct MenuRow: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                    .frame(width: 24)

                Text(title)
                    .foregroundColor(.primary)

                Spacer()

                if title != "Back" {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Long Press Menu Overlay

/// Full-screen overlay container for the long-press context menu
public struct LongPressMenuOverlay: View {
    @Binding var isPresented: Bool
    let coordinate: CLLocationCoordinate2D
    let coordMode: CoordMode

    let onPinChosen: (NatoType) -> Void
    let onFormChosen: (LongPressFormType) -> Void
    let onPhotoChosen: () -> Void
    let onCopyCoordinates: () -> Void

    public init(
        isPresented: Binding<Bool>,
        coordinate: CLLocationCoordinate2D,
        coordMode: CoordMode = .latLon,
        onPinChosen: @escaping (NatoType) -> Void,
        onFormChosen: @escaping (LongPressFormType) -> Void,
        onPhotoChosen: @escaping () -> Void,
        onCopyCoordinates: @escaping () -> Void
    ) {
        self._isPresented = isPresented
        self.coordinate = coordinate
        self.coordMode = coordMode
        self.onPinChosen = onPinChosen
        self.onFormChosen = onFormChosen
        self.onPhotoChosen = onPhotoChosen
        self.onCopyCoordinates = onCopyCoordinates
    }

    public var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }

            // Menu
            LongPressContextMenu(
                isPresented: $isPresented,
                coordinate: coordinate,
                coordMode: coordMode,
                onPinChosen: onPinChosen,
                onFormChosen: onFormChosen,
                onPhotoChosen: onPhotoChosen,
                onCopyCoordinates: onCopyCoordinates
            )
            .frame(maxWidth: 320)
        }
        .animation(.easeInOut(duration: 0.2), value: isPresented)
    }
}

// MARK: - Long Press Action Sheet (Alternative Style)

/// Action sheet style long-press menu (iOS native feel)
public struct LongPressActionSheet: View {
    @Binding var isPresented: Bool
    let coordinate: CLLocationCoordinate2D
    let coordMode: CoordMode

    let onPinChosen: (NatoType) -> Void
    let onFormChosen: (LongPressFormType) -> Void
    let onPhotoChosen: () -> Void
    let onCopyCoordinates: () -> Void

    @State private var showPinPicker = false
    @State private var showFormPicker = false

    public init(
        isPresented: Binding<Bool>,
        coordinate: CLLocationCoordinate2D,
        coordMode: CoordMode = .latLon,
        onPinChosen: @escaping (NatoType) -> Void,
        onFormChosen: @escaping (LongPressFormType) -> Void,
        onPhotoChosen: @escaping () -> Void,
        onCopyCoordinates: @escaping () -> Void
    ) {
        self._isPresented = isPresented
        self.coordinate = coordinate
        self.coordMode = coordMode
        self.onPinChosen = onPinChosen
        self.onFormChosen = onFormChosen
        self.onPhotoChosen = onPhotoChosen
        self.onCopyCoordinates = onCopyCoordinates
    }

    public var body: some View {
        EmptyView()
            .confirmationDialog(
                "Add at \(formattedCoordinate)",
                isPresented: $isPresented,
                titleVisibility: .visible
            ) {
                Button("Drop Pin") {
                    showPinPicker = true
                }

                Button("Create Form") {
                    showFormPicker = true
                }

                Button("Take Photo") {
                    onPhotoChosen()
                }

                Button("Copy Coordinates") {
                    onCopyCoordinates()
                }

                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog(
                "Choose Pin Type",
                isPresented: $showPinPicker,
                titleVisibility: .visible
            ) {
                ForEach([NatoType.infantry, .intelligence, .surveillance, .artillery, .marine, .droneObserved, .op], id: \.self) { pinType in
                    Button(pinType.label) {
                        onPinChosen(pinType)
                    }
                }

                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog(
                "Choose Form Type",
                isPresented: $showFormPicker,
                titleVisibility: .visible
            ) {
                ForEach(LongPressFormType.allCases, id: \.self) { formType in
                    Button(formType.displayName) {
                        onFormChosen(formType)
                    }
                }

                Button("Cancel", role: .cancel) {}
            }
    }

    private var formattedCoordinate: String {
        String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude)
    }
}

// MARK: - Previews

#Preview("Long Press Context Menu") {
    ZStack {
        Color.gray.opacity(0.3)

        LongPressContextMenu(
            isPresented: .constant(true),
            coordinate: CLLocationCoordinate2D(latitude: 59.33, longitude: 18.06),
            coordMode: .latLon,
            onPinChosen: { _ in },
            onFormChosen: { _ in },
            onPhotoChosen: {},
            onCopyCoordinates: {}
        )
        .frame(maxWidth: 320)
    }
}

#Preview("Long Press Menu Overlay") {
    LongPressMenuOverlay(
        isPresented: .constant(true),
        coordinate: CLLocationCoordinate2D(latitude: 59.33, longitude: 18.06),
        onPinChosen: { _ in },
        onFormChosen: { _ in },
        onPhotoChosen: {},
        onCopyCoordinates: {}
    )
}
