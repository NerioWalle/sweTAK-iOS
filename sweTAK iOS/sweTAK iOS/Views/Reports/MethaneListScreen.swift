import SwiftUI

/// Screen showing list of METHANE requests with tabs for Incoming and Outgoing.
/// Mirrors Android MethaneListScreen functionality.
public struct MethaneListScreen: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var methaneVM = MethaneViewModel.shared

    @State private var selectedTab = 0
    @State private var selectedRequest: MethaneRequest?
    @State private var showingDetail = false
    @State private var showingCreate = false

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab selector
                Picker("", selection: $selectedTab) {
                    HStack {
                        Text("Incoming (\(methaneVM.incomingRequests.count))")
                        if methaneVM.unreadIncomingCount > 0 {
                            Circle()
                                .fill(.red)
                                .frame(width: 8, height: 8)
                        }
                    }
                    .tag(0)

                    Text("Outgoing (\(methaneVM.outgoingRequests.count))")
                        .tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                // Content
                if selectedTab == 0 {
                    incomingList
                } else {
                    outgoingList
                }
            }
            .navigationTitle("METHANE Requests")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingCreate = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingDetail) {
                if let request = selectedRequest {
                    MethaneDetailScreen(request: request)
                }
            }
            .sheet(isPresented: $showingCreate) {
                CreateMethaneScreen()
            }
        }
    }

    private var incomingList: some View {
        Group {
            if methaneVM.incomingRequests.isEmpty {
                emptyState(
                    icon: "exclamationmark.triangle",
                    title: "No incoming requests",
                    subtitle: "METHANE requests sent to you will appear here."
                )
            } else {
                List {
                    ForEach(methaneVM.incomingRequests) { request in
                        MethaneListRow(request: request, statuses: [])
                            .onTapGesture {
                                methaneVM.markAsRead(requestId: request.id)
                                selectedRequest = request
                                showingDetail = true
                            }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let request = methaneVM.incomingRequests[index]
                            methaneVM.deleteRequest(requestId: request.id)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private var outgoingList: some View {
        Group {
            if methaneVM.outgoingRequests.isEmpty {
                emptyState(
                    icon: "paperplane",
                    title: "No outgoing requests",
                    subtitle: "METHANE requests you send will appear here."
                )
            } else {
                List {
                    ForEach(methaneVM.outgoingRequests) { request in
                        let statuses = methaneVM.getStatusesForRequest(requestId: request.id)
                        MethaneListRow(request: request, statuses: statuses)
                            .onTapGesture {
                                selectedRequest = request
                                showingDetail = true
                            }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let request = methaneVM.outgoingRequests[index]
                            methaneVM.deleteRequest(requestId: request.id)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundColor(.secondary)

            Text(title)
                .font(.headline)

            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Methane List Row

struct MethaneListRow: View {
    let request: MethaneRequest
    let statuses: [MethaneRecipientStatus]

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM HH:mm"
        return formatter
    }

    var body: some View {
        HStack(spacing: 12) {
            // Unread indicator
            if request.direction == .incoming && !request.isRead {
                Circle()
                    .fill(.blue)
                    .frame(width: 8, height: 8)
            }

            // Emergency icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundColor(.red)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    // Incident type badge
                    IncidentTypeBadge(incidentType: request.incidentType)

                    Spacer()

                    Text(dateFormatter.string(from: Date(timeIntervalSince1970: Double(request.createdAtMillis) / 1000)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if request.direction == .incoming {
                    Text("From: \(request.senderCallsign.isEmpty ? String(request.senderDeviceId.prefix(8)) : request.senderCallsign)")
                        .font(.subheadline)
                } else {
                    let totalRecipients = request.recipientDeviceIds.count
                    let deliveredCount = statuses.filter { $0.isDelivered }.count
                    let readCount = statuses.filter { $0.isRead }.count

                    Text("To: \(totalRecipients) recipient\(totalRecipients == 1 ? "" : "s")")
                        .font(.subheadline)

                    if totalRecipients > 0 {
                        Text("Delivered: \(deliveredCount), Read: \(readCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Casualty summary
                let totalCasualties = request.totalCasualties
                Text(totalCasualties > 0
                     ? "Casualties: \(totalCasualties) (P1:\(request.casualtyCountP1), P2:\(request.casualtyCountP2), P3:\(request.casualtyCountP3), KIA:\(request.casualtyCountDeceased))"
                     : "No casualties reported")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Incident Type Badge

struct IncidentTypeBadge: View {
    let incidentType: String

    var body: some View {
        Text(incidentType.isEmpty ? "INCIDENT" : incidentType)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.red)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color.red.opacity(0.15))
            .cornerRadius(4)
    }
}

// MARK: - Preview

#Preview("METHANE List") {
    MethaneListScreen()
}
