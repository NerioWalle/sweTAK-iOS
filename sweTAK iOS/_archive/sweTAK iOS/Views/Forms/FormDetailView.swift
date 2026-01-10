import SwiftUI

/// View for displaying the details of a submitted linked form.
public struct FormDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let form: LinkedForm

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }

    public init(form: LinkedForm) {
        self.form = form
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    headerCard

                    // Form content based on type
                    if form.formType == FormType.sevenS.rawValue {
                        sevenSContent
                    } else if form.formType == FormType.indirectFire.rawValue {
                        ifsContent
                    } else {
                        rawContent
                    }
                }
                .padding()
            }
            .navigationTitle(formTypeTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var formTypeTitle: String {
        if form.formType == FormType.sevenS.rawValue {
            return "7S Report"
        } else if form.formType == FormType.indirectFire.rawValue {
            return "IFS Request"
        }
        return "Form"
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: form.formType == FormType.sevenS.rawValue ? "doc.fill" : "scope")
                    .font(.title2)
                    .foregroundColor(.blue)

                VStack(alignment: .leading) {
                    Text(formTypeTitle)
                        .font(.headline)
                    Text("by \(form.authorCallsign)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            Divider()

            Text(dateFormatter.string(from: Date(timeIntervalSince1970: Double(form.submittedAtMillis) / 1000)))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - 7S Content

    private var sevenSContent: some View {
        Group {
            if let formData = SevenSFormData.fromJSONString(form.formData) {
                VStack(alignment: .leading, spacing: 12) {
                    FormFieldCard(label: "Date/Time", value: formData.dateTime, number: "1")
                    FormFieldCard(label: "Place", value: formData.place, number: "2")
                    FormFieldCard(label: "Force Size", value: formData.forceSize, number: "3")
                    FormFieldCard(label: "Type", value: formData.type, number: "4")
                    FormFieldCard(label: "Occupation", value: formData.occupation, number: "5")
                    FormFieldCard(label: "Symbols", value: formData.symbols, number: "6")
                    FormFieldCard(label: "Reporter", value: formData.reporter, number: "7")
                }
            } else {
                rawContent
            }
        }
    }

    // MARK: - IFS Content

    private var ifsContent: some View {
        Group {
            if let formData = IndirectFireFormData.fromJSONString(form.formData) {
                VStack(alignment: .leading, spacing: 16) {
                    // Observer section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("OBSERVER")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)

                        FormFieldCard(label: "Callsign", value: formData.observer)
                        FormFieldCard(label: "Position", value: formData.observerPosition)
                    }

                    // Request section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("REQUEST")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)

                        FormFieldCard(label: "Type", value: formData.requestType.displayName)
                    }

                    // Target section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TARGET")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)

                        FormFieldCard(label: "Description", value: formData.targetDescription)

                        if let lat = formData.targetLatitude, let lon = formData.targetLongitude {
                            FormFieldCard(label: "Position", value: String(format: "%.6f, %.6f", lat, lon))
                        }
                    }

                    // Enemy section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ENEMY")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)

                        FormFieldCard(label: "Forces", value: formData.enemyForces)
                        FormFieldCard(label: "Activity", value: formData.enemyActivity)
                        FormFieldCard(label: "Terrain", value: formData.targetTerrain)
                    }

                    // Fire parameters section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("FIRE PARAMETERS")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)

                        HStack(spacing: 12) {
                            FireParamCard(label: "Width", value: formData.widthMeters.map { "\($0) m" } ?? "-")
                            FireParamCard(label: "Angle", value: formData.angleOfViewMils.map { "\($0) mils" } ?? "-")
                            FireParamCard(label: "Distance", value: formData.distanceMeters.map { "\($0) m" } ?? "-")
                        }
                    }
                }
            } else {
                rawContent
            }
        }
    }

    // MARK: - Raw Content

    private var rawContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RAW DATA")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            Text(form.formData)
                .font(.system(.body, design: .monospaced))
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
        }
    }
}

// MARK: - Form Field Card

private struct FormFieldCard: View {
    let label: String
    let value: String
    var number: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if let number = number {
                Text(number)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 18, height: 18)
                    .background(Color.blue)
                    .cornerRadius(9)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(value.isEmpty ? "-" : value)
                    .font(.body)
            }

            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Fire Parameter Card

private struct FireParamCard: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .foregroundColor(.primary)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview("7S Form Detail") {
    FormDetailView(form: LinkedForm(
        opPinId: 1,
        opOriginDeviceId: "device-123",
        formType: FormType.sevenS.rawValue,
        formData: SevenSFormData(
            dateTime: "301430",
            place: "59.330000, 18.060000",
            forceSize: "~10 personnel",
            type: "Infantry patrol",
            occupation: "Moving east along road",
            symbols: "Woodland camo, AK-pattern rifles",
            reporter: "Alpha-1"
        ).toJSONString(),
        authorCallsign: "Alpha-1"
    ))
}

#Preview("IFS Form Detail") {
    FormDetailView(form: LinkedForm(
        opPinId: 1,
        opOriginDeviceId: "device-123",
        formType: FormType.indirectFire.rawValue,
        formData: IndirectFireFormData(
            observer: "Alpha-1",
            requestType: .fight,
            targetDescription: "Enemy mortar position",
            observerPosition: "59.330000, 18.060000",
            enemyForces: "2x 82mm mortars with crew",
            enemyActivity: "Setting up firing position",
            targetTerrain: "Open field",
            widthMeters: 50,
            angleOfViewMils: 1600,
            distanceMeters: 800,
            targetLatitude: 59.34,
            targetLongitude: 18.07
        ).toJSONString(),
        authorCallsign: "Alpha-1"
    ))
}
