import SwiftUI
import MapKit

/// Detail view for a METHANE emergency notification request.
/// Mirrors Android MethaneDetailScreen functionality.
public struct MethaneDetailScreen: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var methaneVM = MethaneViewModel.shared

    let request: MethaneRequest
    @State private var showingDuplicate = false

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }

    public init(request: MethaneRequest) {
        self.request = request
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    // Header section
                    Section {
                        IncidentTypeBadge(incidentType: request.incidentType)
                            .padding(.vertical, 4)

                        HStack {
                            Text("Created")
                            Spacer()
                            Text(dateFormatter.string(from: Date(timeIntervalSince1970: Double(request.createdAtMillis) / 1000)))
                                .foregroundColor(.secondary)
                        }

                        if request.direction == .incoming {
                            HStack {
                                Text("From")
                                Spacer()
                                Text(request.senderCallsign.isEmpty ? String(request.senderDeviceId.prefix(8)) : request.senderCallsign)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            let statuses = methaneVM.getStatusesForRequest(requestId: request.id)
                            HStack {
                                Text("Recipients")
                                Spacer()
                                Text("\(request.recipientDeviceIds.count)")
                                    .foregroundColor(.secondary)
                            }

                            let deliveredCount = statuses.filter { $0.isDelivered }.count
                            let readCount = statuses.filter { $0.isRead }.count

                            HStack {
                                Text("Status")
                                Spacer()
                                Text("Delivered: \(deliveredCount), Read: \(readCount)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // M - Military Details
                    Section {
                        DetailRow(label: "Callsign", value: request.callsign)
                        DetailRow(label: "Unit", value: request.unit)
                    } header: {
                        SectionHeader(letter: "M", title: "MILITARY DETAILS")
                    }

                    // E - Exact Location
                    Section {
                        if !request.incidentLocation.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Location Description")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(request.incidentLocation)
                            }
                        }

                        if let lat = request.incidentLatitude, let lon = request.incidentLongitude {
                            HStack {
                                Text("Coordinates")
                                Spacer()
                                Text(String(format: "%.6f, %.6f", lat, lon))
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }

                            // Mini map preview
                            Map(position: .constant(MapCameraPosition.region(MKCoordinateRegion(
                                center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                            )))) {
                                Marker("Incident", coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
                            }
                            .frame(height: 150)
                            .cornerRadius(8)
                        }
                    } header: {
                        SectionHeader(letter: "E", title: "EXACT LOCATION")
                    }

                    // T - Time and Type
                    Section {
                        DetailRow(label: "Time", value: request.incidentTime)
                        DetailRow(label: "Type", value: request.incidentType)
                    } header: {
                        SectionHeader(letter: "T", title: "TIME AND TYPE")
                    }

                    // H - Hazards
                    if !request.hazards.isEmpty {
                        Section {
                            Text(request.hazards)
                        } header: {
                            SectionHeader(letter: "H", title: "HAZARDS")
                        }
                    }

                    // A - Approach Routes
                    Section {
                        if !request.approachRoutes.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Approach Routes")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(request.approachRoutes)
                            }
                        }

                        if !request.hlsLocation.isEmpty {
                            DetailRow(label: "HLS Location", value: request.hlsLocation)
                        }

                        if let hlsLat = request.hlsLatitude, let hlsLon = request.hlsLongitude {
                            HStack {
                                Text("HLS Coordinates")
                                Spacer()
                                Text(String(format: "%.6f, %.6f", hlsLat, hlsLon))
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                    } header: {
                        SectionHeader(letter: "A", title: "APPROACH ROUTES & HLS")
                    }

                    // N - Casualties
                    Section {
                        HStack(spacing: 16) {
                            CasualtyBadge(label: "P1", count: request.casualtyCountP1, color: .red)
                            CasualtyBadge(label: "P2", count: request.casualtyCountP2, color: .yellow)
                            CasualtyBadge(label: "P3", count: request.casualtyCountP3, color: .green)
                            CasualtyBadge(label: "KIA", count: request.casualtyCountDeceased, color: .gray)
                        }
                        .padding(.vertical, 4)

                        HStack {
                            Text("Total")
                            Spacer()
                            Text("\(request.totalCasualties)")
                                .fontWeight(.bold)
                        }

                        if !request.casualtyDetails.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Details")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(request.casualtyDetails)
                            }
                        }
                    } header: {
                        SectionHeader(letter: "N", title: "CASUALTIES")
                    }

                    // E - Expected Response
                    Section {
                        if !request.assetsPresent.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Assets Present")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(request.assetsPresent)
                            }
                        }

                        if !request.assetsRequired.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Assets Required")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(request.assetsRequired)
                            }
                        }
                    } header: {
                        SectionHeader(letter: "E", title: "EXPECTED RESPONSE")
                    }
                }

                // Action buttons outside the List
                VStack(spacing: 12) {
                    Button {
                        showingDuplicate = true
                    } label: {
                        HStack {
                            Image(systemName: "doc.on.doc")
                            Text("Duplicate Request")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }

                    Button {
                        methaneVM.deleteRequest(requestId: request.id)
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Request")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
                .padding()
            }
            .navigationTitle("METHANE Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingDuplicate) {
                CreateMethaneScreen(duplicateFrom: request)
            }
        }
    }
}

// MARK: - Detail Row

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value.isEmpty ? "-" : value)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Section Header

private struct SectionHeader: View {
    let letter: String
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            Text(letter)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.red)
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Casualty Badge

private struct CasualtyBadge: View {
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview("METHANE Detail") {
    MethaneDetailScreen(request: MethaneRequest(
        senderDeviceId: "device-123",
        senderCallsign: "Alpha-1",
        callsign: "Alpha-1",
        unit: "1st Platoon",
        incidentLocation: "Near building complex, east side",
        incidentLatitude: 59.33,
        incidentLongitude: 18.06,
        incidentTime: "14:30",
        incidentType: "IED",
        hazards: "Possible secondary devices",
        approachRoutes: "From north via main road",
        hlsLocation: "Open field 200m south",
        hlsLatitude: 59.328,
        hlsLongitude: 18.06,
        casualtyCountP1: 2,
        casualtyCountP2: 1,
        casualtyCountP3: 3,
        casualtyCountDeceased: 0,
        casualtyDetails: "2 severe leg injuries, 1 concussion",
        assetsPresent: "1 medic, 2 stretchers",
        assetsRequired: "MEDEVAC helicopter, additional medics",
        recipientDeviceIds: ["device-456"],
        direction: .outgoing
    ))
}
