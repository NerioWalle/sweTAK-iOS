import SwiftUI

/// Sheet view for creating an Indirect Fire Support (IFS) request.
/// Used for requesting artillery/mortar fire support.
public struct IndirectFireFormSheet: View {
    @Environment(\.dismiss) private var dismiss

    let draft: IndirectFireFormData
    let targetCoordinateText: String?
    let onSubmit: (IndirectFireFormData) -> Void

    @State private var formData: IndirectFireFormData
    @State private var targetPosition: String
    @State private var widthText: String
    @State private var angleText: String
    @State private var distanceText: String

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case observer, targetDesc, targetPos, enemyForces, enemyActivity
        case targetTerrain, width, angle, distance
    }

    public init(
        draft: IndirectFireFormData,
        targetCoordinateText: String?,
        onSubmit: @escaping (IndirectFireFormData) -> Void
    ) {
        self.draft = draft
        self.targetCoordinateText = targetCoordinateText
        self.onSubmit = onSubmit
        self._formData = State(initialValue: draft)

        // Initialize target position text
        let targetText: String
        if let text = targetCoordinateText {
            targetText = text
        } else if let lat = draft.targetLatitude, let lon = draft.targetLongitude {
            targetText = String(format: "%.6f, %.6f", lat, lon)
        } else {
            targetText = ""
        }
        self._targetPosition = State(initialValue: targetText)

        // Initialize numeric fields
        self._widthText = State(initialValue: draft.widthMeters.map { String($0) } ?? "")
        self._angleText = State(initialValue: draft.angleOfViewMils.map { String($0) } ?? "")
        self._distanceText = State(initialValue: draft.distanceMeters.map { String($0) } ?? "")
    }

    public var body: some View {
        NavigationStack {
            Form {
                // Observer section
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Observer Callsign")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Your callsign", text: $formData.observer)
                            .focused($focusedField, equals: .observer)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .targetDesc }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Observer Position")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formData.observerPosition.isEmpty ? "Unknown" : formData.observerPosition)
                            .foregroundColor(.secondary)
                            .font(.system(.body, design: .monospaced))
                    }
                } header: {
                    Text("OBSERVER")
                }

                // Request type section
                Section {
                    Picker("Request Type", selection: $formData.requestType) {
                        ForEach(IFSRequestType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("REQUEST TYPE")
                }

                // Target section
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Target Description")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("What is the target?", text: $formData.targetDescription, axis: .vertical)
                            .lineLimit(2...4)
                            .focused($focusedField, equals: .targetDesc)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .targetPos }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Target Position")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Coordinates", text: $targetPosition)
                            .font(.system(.body, design: .monospaced))
                            .focused($focusedField, equals: .targetPos)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .enemyForces }
                    }
                } header: {
                    Text("TARGET")
                }

                // Enemy section
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enemy Forces")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Type and size of enemy", text: $formData.enemyForces, axis: .vertical)
                            .lineLimit(2...4)
                            .focused($focusedField, equals: .enemyForces)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .enemyActivity }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enemy Activity")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("What is the enemy doing?", text: $formData.enemyActivity, axis: .vertical)
                            .lineLimit(2...4)
                            .focused($focusedField, equals: .enemyActivity)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .targetTerrain }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Target Terrain")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Open, wooded, urban, etc.", text: $formData.targetTerrain)
                            .focused($focusedField, equals: .targetTerrain)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .width }
                    }
                } header: {
                    Text("ENEMY")
                }

                // Fire parameters section
                Section {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Width (m)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("0", text: $widthText)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)
                                .focused($focusedField, equals: .width)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Angle (mils)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("0", text: $angleText)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)
                                .focused($focusedField, equals: .angle)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Distance (m)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("0", text: $distanceText)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)
                                .focused($focusedField, equals: .distance)
                        }
                    }

                    if formData.distanceMeters != nil || formData.angleOfViewMils != nil {
                        Text("Distance and angle auto-calculated from observer and target positions")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("FIRE PARAMETERS")
                }
            }
            .navigationTitle("IFS Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        submitForm()
                    } label: {
                        Image(systemName: "paperplane.fill")
                    }
                    .disabled(formData.observer.isEmpty || targetPosition.isEmpty)
                }

                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("Done") {
                            focusedField = nil
                        }
                    }
                }
            }
        }
    }

    private func submitForm() {
        // Update form data with text field values
        var finalData = formData
        finalData.widthMeters = Int(widthText)
        finalData.angleOfViewMils = Int(angleText)
        finalData.distanceMeters = Int(distanceText)

        onSubmit(finalData)
        dismiss()
    }
}

// MARK: - Preview

#Preview("IFS Form") {
    IndirectFireFormSheet(
        draft: IndirectFireFormData.createDraft(
            observer: "Alpha-1",
            observerLatitude: 59.33,
            observerLongitude: 18.06,
            observerPositionText: "59.330000, 18.060000",
            targetLatitude: 59.34,
            targetLongitude: 18.07
        ),
        targetCoordinateText: "59.340000, 18.070000"
    ) { formData in
        print("Submitted: \(formData)")
    }
}
