import SwiftUI
import UIKit
import CoreLocation

// MARK: - Coordinate Input Dialog

/// Dialog for entering coordinates to navigate to
public struct CoordinateInputDialog: View {
    let coordMode: CoordMode
    @Binding var text: String
    @Binding var isPresented: Bool
    let error: String?
    let onGoThere: (String) -> Void

    @FocusState private var isFocused: Bool

    public init(
        coordMode: CoordMode,
        text: Binding<String>,
        isPresented: Binding<Bool>,
        error: String?,
        onGoThere: @escaping (String) -> Void
    ) {
        self.coordMode = coordMode
        self._text = text
        self._isPresented = isPresented
        self.error = error
        self.onGoThere = onGoThere
    }

    public var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Give coordinates (\(coordMode.displayName)) for placing the crosshair there.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextField(placeholder, text: $text)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.allCharacters)
                    .focused($isFocused)
                    .onSubmit {
                        onGoThere(text.trimmingCharacters(in: .whitespaces))
                    }

                if let error = error {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Go to coordinates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Go there") {
                        onGoThere(text.trimmingCharacters(in: .whitespaces))
                    }
                }
            }
            .onAppear {
                isFocused = true
            }
        }
    }

    private var placeholder: String {
        switch coordMode {
        case .mgrs: return "33VWN12345678"
        case .latLon: return "57.70000, 11.90000"
        }
    }
}

// MARK: - Pin Edit Dialog

/// Dialog for editing a pin's title, description, and type
public struct PinEditDialog: View {
    @Binding var isPresented: Bool
    @Binding var title: String
    @Binding var description: String
    @Binding var pinType: NatoType
    let onConfirm: () -> Void

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case title, description
    }

    private let editableTypes: [NatoType] = [
        .infantry, .intelligence, .surveillance, .artillery,
        .marine, .droneObserved, .form7S, .formIFS
    ]

    public init(
        isPresented: Binding<Bool>,
        title: Binding<String>,
        description: Binding<String>,
        pinType: Binding<NatoType>,
        onConfirm: @escaping () -> Void
    ) {
        self._isPresented = isPresented
        self._title = title
        self._description = description
        self._pinType = pinType
        self.onConfirm = onConfirm
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Subject", text: $title)
                        .focused($focusedField, equals: .title)

                    TextEditor(text: $description)
                        .frame(minHeight: 80)
                        .focused($focusedField, equals: .description)
                }

                Section("Type") {
                    Picker("Pin Type", selection: $pinType) {
                        ForEach(editableTypes, id: \.self) { type in
                            HStack {
                                NatoPinIconView(pinType: type, size: 20)
                                Text(type.label)
                            }
                            .tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle("Edit Pin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onConfirm()
                        isPresented = false
                    }
                }
            }
            .onAppear {
                focusedField = .title
            }
        }
    }
}

// MARK: - Pin View Dialog

/// Dialog for viewing a pin's details (read-only)
public struct PinViewDialog: View {
    let pin: NatoPin
    let coordMode: CoordMode
    @Binding var isPresented: Bool
    let onSaveToPhotos: ((String) -> Void)?
    let onSaveToFiles: ((String) -> Void)?
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?

    public init(
        pin: NatoPin,
        isPresented: Binding<Bool>,
        coordMode: CoordMode = .mgrs,
        onSaveToPhotos: ((String) -> Void)? = nil,
        onSaveToFiles: ((String) -> Void)? = nil,
        onEdit: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.pin = pin
        self.coordMode = coordMode
        self._isPresented = isPresented
        self.onSaveToPhotos = onSaveToPhotos
        self.onSaveToFiles = onSaveToFiles
        self.onEdit = onEdit
        self.onDelete = onDelete
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Pin type icon and title
                    HStack {
                        NatoPinIconView(pinType: pin.type, size: 28, color: iconColor)

                        Text(displayTitle)
                            .font(.title2)
                            .fontWeight(.semibold)
                    }

                    Divider()

                    // Description
                    if !formattedDescription.isEmpty {
                        Text(formattedDescription)
                            .font(.body)
                    }

                    // Metadata
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Author: \(authorName)", systemImage: "person.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Label("Created: \(timestampText)", systemImage: "clock.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Label("Location: \(coordinateText)", systemImage: "mappin.circle.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Photo if available
                    if let photoUri = pin.photoUri, !photoUri.isEmpty {
                        Divider()

                        // Decode base64 image and display
                        if let imageData = Data(base64Encoded: photoUri),
                           let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 300)
                                .cornerRadius(8)
                        } else {
                            // Fallback placeholder if decoding fails
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.systemGray5))
                                    .frame(height: 200)

                                VStack {
                                    Image(systemName: "photo")
                                        .font(.largeTitle)
                                        .foregroundColor(.secondary)
                                    Text("Photo attached")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        if let onSaveToPhotos = onSaveToPhotos {
                            Button {
                                onSaveToPhotos(photoUri)
                            } label: {
                                Label("Save to Photos", systemImage: "photo.on.rectangle")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }

                        if let onSaveToFiles = onSaveToFiles {
                            Button {
                                onSaveToFiles(photoUri)
                            } label: {
                                Label("Save to Files", systemImage: "folder")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Pin Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if onDelete != nil {
                        Button(role: .destructive) {
                            onDelete?()
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if onEdit != nil {
                            Button {
                                onEdit?()
                            } label: {
                                Image(systemName: "pencil")
                            }
                        }

                        Button("Close") {
                            isPresented = false
                        }
                    }
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var displayTitle: String {
        pin.title.isEmpty ? pin.type.label : pin.title
    }

    private var formattedDescription: String {
        // For form-type pins, reformat coordinates based on viewer's preference
        formatFormDescriptionForViewer(
            pinType: pin.type,
            description: pin.description,
            coordMode: coordMode
        )
    }

    private var authorName: String {
        pin.authorCallsign.isEmpty ? "Unknown" : pin.authorCallsign
    }

    private var timestampText: String {
        let date = Date(timeIntervalSince1970: Double(pin.createdAtMillis) / 1000.0)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }

    private var coordinateText: String {
        switch coordMode {
        case .mgrs:
            return MapCoordinateUtils.toMgrs(lat: pin.latitude, lon: pin.longitude)
        case .latLon:
            return String(format: "%.6f, %.6f", pin.latitude, pin.longitude)
        }
    }

    private var iconColor: Color {
        switch pin.type {
        case .infantry, .marine:
            return .red
        case .intelligence, .surveillance, .droneObserved:
            return .orange
        case .artillery:
            return .purple
        case .op:
            return .green
        case .photo:
            return .blue
        case .form7S, .formIFS:
            return .gray
        }
    }
}

// MARK: - Pin Create Dialog

/// Dialog for creating a new pin at specified coordinates
public struct PinCreateDialog: View {
    @Binding var isPresented: Bool
    let latitude: Double
    let longitude: Double
    let onConfirm: (NatoPin) -> Void

    @State private var title = ""
    @State private var description = ""
    @State private var pinType: NatoType = .infantry

    @ObservedObject private var settingsVM = SettingsViewModel.shared

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case title, description
    }

    private let createableTypes: [NatoType] = [
        .infantry, .intelligence, .surveillance, .artillery,
        .marine, .droneObserved, .op, .photo
    ]

    public init(
        isPresented: Binding<Bool>,
        latitude: Double,
        longitude: Double,
        onConfirm: @escaping (NatoPin) -> Void
    ) {
        self._isPresented = isPresented
        self.latitude = latitude
        self.longitude = longitude
        self.onConfirm = onConfirm
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Subject", text: $title)
                        .focused($focusedField, equals: .title)

                    TextEditor(text: $description)
                        .frame(minHeight: 80)
                        .focused($focusedField, equals: .description)
                }

                Section("Type") {
                    Picker("Pin Type", selection: $pinType) {
                        ForEach(createableTypes, id: \.self) { type in
                            HStack {
                                NatoPinIconView(pinType: type, size: 20)
                                Text(type.label)
                            }
                            .tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Location") {
                    HStack {
                        Text("Coordinates")
                        Spacer()
                        Text(String(format: "%.5f, %.5f", latitude, longitude))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Drop Pin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let newPin = NatoPin(
                            latitude: latitude,
                            longitude: longitude,
                            type: pinType,
                            title: title.trimmingCharacters(in: .whitespaces),
                            description: description.trimmingCharacters(in: .whitespaces),
                            authorCallsign: settingsVM.callsign,
                            originDeviceId: settingsVM.deviceId
                        )
                        onConfirm(newPin)
                        isPresented = false
                    }
                }
            }
            .onAppear {
                focusedField = .title
            }
        }
    }
}

// MARK: - Pin Delete Confirmation Dialog

/// Confirmation dialog for deleting a pin
public struct PinDeleteConfirmation: View {
    let pin: NatoPin
    @Binding var isPresented: Bool
    let onConfirm: () -> Void

    public init(
        pin: NatoPin,
        isPresented: Binding<Bool>,
        onConfirm: @escaping () -> Void
    ) {
        self.pin = pin
        self._isPresented = isPresented
        self.onConfirm = onConfirm
    }

    public var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "trash.fill")
                .font(.largeTitle)
                .foregroundColor(.red)

            Text("Delete Pin?")
                .font(.headline)

            Text("Are you sure you want to delete \"\(pin.title.isEmpty ? pin.type.label : pin.title)\"?")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)

                Button("Delete") {
                    onConfirm()
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
        .padding()
    }
}

// MARK: - Previews

#Preview("Coordinate Input") {
    CoordinateInputDialog(
        coordMode: .mgrs,
        text: .constant(""),
        isPresented: .constant(true),
        error: nil,
        onGoThere: { _ in }
    )
}

#Preview("Pin Edit") {
    PinEditDialog(
        isPresented: .constant(true),
        title: .constant("Enemy position"),
        description: .constant("Infantry squad spotted"),
        pinType: .constant(.infantry),
        onConfirm: {}
    )
}

#Preview("Pin View") {
    PinViewDialog(
        pin: NatoPin(
            latitude: 59.33,
            longitude: 18.06,
            type: .infantry,
            title: "Enemy position",
            description: "Infantry squad spotted moving east",
            authorCallsign: "Alpha-1"
        ),
        isPresented: .constant(true)
    )
}

// MARK: - Photo Capture View

/// A view that presents the camera for capturing geotagged photos
public struct PhotoCaptureView: View {
    @Environment(\.dismiss) private var dismiss

    let coordinate: CLLocationCoordinate2D
    let onCapture: (UIImage, CLLocationCoordinate2D?, String, String) -> Void

    @State private var showingCamera = false
    @State private var capturedImage: UIImage?
    @State private var subject: String = ""
    @State private var description: String = ""

    @FocusState private var focusedField: Field?
    private enum Field: Hashable {
        case subject, description
    }

    public init(
        coordinate: CLLocationCoordinate2D,
        onCapture: @escaping (UIImage, CLLocationCoordinate2D?, String, String) -> Void
    ) {
        self.coordinate = coordinate
        self.onCapture = onCapture
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let image = capturedImage {
                        // Show captured image
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 250)
                            .cornerRadius(12)

                        Text("Location: \(String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude))")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        // Subject and description fields
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Subject")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("Enter subject", text: $subject)
                                    .textFieldStyle(.roundedBorder)
                                    .focused($focusedField, equals: .subject)
                                    .submitLabel(.next)
                                    .onSubmit { focusedField = .description }
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Description")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("Enter description", text: $description, axis: .vertical)
                                    .textFieldStyle(.roundedBorder)
                                    .lineLimit(3...5)
                                    .focused($focusedField, equals: .description)
                            }
                        }
                        .padding(.horizontal)

                        HStack(spacing: 20) {
                            Button("Retake") {
                                capturedImage = nil
                                showingCamera = true
                            }
                            .buttonStyle(.bordered)

                            Button("Save Photo") {
                                onCapture(image, coordinate, subject, description)
                                dismiss()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    } else {
                        // Show camera prompt
                        VStack(spacing: 16) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)

                            Text("Take a geotagged photo at this location")
                                .font(.headline)
                                .multilineTextAlignment(.center)

                            Text(String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude))
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Button {
                                showingCamera = true
                            } label: {
                                Label("Open Camera", systemImage: "camera")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .padding(.top)
                        }
                        .padding()
                    }
                }
                .padding()
            }
            .navigationTitle("Capture Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingCamera) {
                CameraViewWrapper { image in
                    capturedImage = image
                }
            }
        }
    }
}

// MARK: - Camera View Wrapper

struct CameraViewWrapper: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> CameraCoordinator {
        CameraCoordinator(onCapture: onCapture)
    }
}

class CameraCoordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    let onCapture: (UIImage) -> Void

    init(onCapture: @escaping (UIImage) -> Void) {
        self.onCapture = onCapture
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[.originalImage] as? UIImage {
            onCapture(image)
        }
        picker.dismiss(animated: true)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}

#Preview("Photo Capture") {
    PhotoCaptureView(
        coordinate: CLLocationCoordinate2D(latitude: 59.33, longitude: 18.06)
    ) { image, location, subject, description in
        print("Captured photo at \(String(describing: location)) - Subject: \(subject)")
    }
}

#Preview("Pin Create") {
    PinCreateDialog(
        isPresented: .constant(true),
        latitude: 59.33,
        longitude: 18.06,
        onConfirm: { _ in }
    )
}
