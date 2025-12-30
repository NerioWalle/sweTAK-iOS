import SwiftUI

/// Sheet view for creating a 7S observation report.
/// 7S: Scene, Size, Sort, Sysselsattning, Symbols, Signal, Samband
public struct SevenSFormSheet: View {
    @Environment(\.dismiss) private var dismiss

    let draft: SevenSFormData
    let onSubmit: (SevenSFormData) -> Void

    @State private var formData: SevenSFormData

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case dateTime, place, forceSize, type, occupation, symbols, reporter
    }

    public init(draft: SevenSFormData, onSubmit: @escaping (SevenSFormData) -> Void) {
        self.draft = draft
        self.onSubmit = onSubmit
        self._formData = State(initialValue: draft)
    }

    public var body: some View {
        NavigationStack {
            Form {
                // Scene section
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Date and Time")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("DDHHMM", text: $formData.dateTime)
                            .textInputAutocapitalization(.characters)
                            .focused($focusedField, equals: .dateTime)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .place }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Place")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Location (MGRS or coordinates)", text: $formData.place)
                            .focused($focusedField, equals: .place)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .forceSize }
                    }
                } header: {
                    SectionHeaderWithNumber(number: "1", title: "SCENE")
                }

                // Size section
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Force Size")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Number of personnel/vehicles", text: $formData.forceSize)
                            .keyboardType(.default)
                            .focused($focusedField, equals: .forceSize)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .type }
                    }
                } header: {
                    SectionHeaderWithNumber(number: "2", title: "SIZE")
                }

                // Sort section
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Type of Forces")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Infantry, armor, artillery, etc.", text: $formData.type)
                            .focused($focusedField, equals: .type)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .occupation }
                    }
                } header: {
                    SectionHeaderWithNumber(number: "3", title: "SORT")
                }

                // Occupation section
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Occupation/Activity")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("What are they doing?", text: $formData.occupation, axis: .vertical)
                            .lineLimit(2...4)
                            .focused($focusedField, equals: .occupation)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .symbols }
                    }
                } header: {
                    SectionHeaderWithNumber(number: "4", title: "OCCUPATION")
                }

                // Symbols section
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Distinguishing Features")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Markings, uniforms, equipment", text: $formData.symbols, axis: .vertical)
                            .lineLimit(2...4)
                            .focused($focusedField, equals: .symbols)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .reporter }
                    }
                } header: {
                    SectionHeaderWithNumber(number: "5", title: "SYMBOLS")
                }

                // Signal section (reporter)
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reporter Callsign")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Your callsign", text: $formData.reporter)
                            .focused($focusedField, equals: .reporter)
                            .submitLabel(.done)
                    }
                } header: {
                    SectionHeaderWithNumber(number: "6", title: "SIGNAL")
                }
            }
            .navigationTitle("7S Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        onSubmit(formData)
                        dismiss()
                    } label: {
                        Image(systemName: "paperplane.fill")
                    }
                    .disabled(formData.place.isEmpty)
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
}

// MARK: - Section Header with Number

private struct SectionHeaderWithNumber: View {
    let number: String
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            Text(number)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Color.blue)
                .cornerRadius(10)

            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }
}

// MARK: - Preview

#Preview("7S Form") {
    SevenSFormSheet(
        draft: SevenSFormData.createDraft(
            reporter: "Alpha-1",
            latitude: 59.33,
            longitude: 18.06,
            placeText: "59.330000, 18.060000"
        )
    ) { formData in
        print("Submitted: \(formData)")
    }
}
