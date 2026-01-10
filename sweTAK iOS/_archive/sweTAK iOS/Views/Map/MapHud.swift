import SwiftUI
import CoreLocation

// MARK: - HUD Overlay

/// HUD overlay showing current position, crosshair coordinates, altitude, and distance
public struct HudOverlay: View {
    let myPosition: CLLocationCoordinate2D?
    let crosshairPosition: CLLocationCoordinate2D?
    let coordMode: CoordMode
    let myAltitudeMeters: Double?
    let crosshairAltitudeMeters: Double?
    let unitSystem: UnitSystem

    public init(
        myPosition: CLLocationCoordinate2D?,
        crosshairPosition: CLLocationCoordinate2D?,
        coordMode: CoordMode,
        myAltitudeMeters: Double? = nil,
        crosshairAltitudeMeters: Double? = nil,
        unitSystem: UnitSystem = .metric
    ) {
        self.myPosition = myPosition
        self.crosshairPosition = crosshairPosition
        self.coordMode = coordMode
        self.myAltitudeMeters = myAltitudeMeters
        self.crosshairAltitudeMeters = crosshairAltitudeMeters
        self.unitSystem = unitSystem
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // My position
            HudRow(
                label: "My position:",
                value: myPositionText
            )

            // Crosshair position
            HudRow(
                label: "Crosshair:",
                value: crosshairText
            )

            // Altitudes
            if let myAlt = myAltitudeMeters {
                HudRow(
                    label: "Alt (my pos):",
                    value: formatAltitude(myAlt)
                )
            }

            HudRow(
                label: "Alt (crosshair):",
                value: crosshairAltitudeMeters.map { formatAltitude($0) } ?? "—"
            )

            // Distance
            if let distance = calculatedDistance {
                HudRow(
                    label: "Distance:",
                    value: formatDistance(distance)
                )
            }

            // Bearing
            if let bearing = calculatedBearing {
                HudRow(
                    label: "Bearing:",
                    value: formatBearing(bearing)
                )
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }

    // MARK: - Position Text

    private var myPositionText: String {
        guard let pos = myPosition else {
            return "(unknown)"
        }
        return formatCoordinate(pos)
    }

    private var crosshairText: String {
        guard let pos = crosshairPosition else {
            return "(centered / not moved)"
        }
        return formatCoordinate(pos)
    }

    private func formatCoordinate(_ coord: CLLocationCoordinate2D) -> String {
        MapCoordinateUtils.formatCoordinate(lat: coord.latitude, lon: coord.longitude, mode: coordMode)
    }

    // MARK: - Altitude Formatting

    private func formatAltitude(_ meters: Double) -> String {
        switch unitSystem {
        case .metric:
            return String(format: "%.0f m", meters)
        case .imperial:
            let feet = meters * 3.28084
            return String(format: "%.0f ft", feet)
        }
    }

    // MARK: - Distance Calculation

    private var calculatedDistance: Double? {
        guard let my = myPosition, let ch = crosshairPosition else {
            return nil
        }
        return haversineDistance(from: my, to: ch)
    }

    private var calculatedBearing: Double? {
        guard let my = myPosition, let ch = crosshairPosition else {
            return nil
        }
        return bearing(from: my, to: ch)
    }

    private func formatDistance(_ meters: Double) -> String {
        switch unitSystem {
        case .metric:
            if meters < 1000 {
                return String(format: "%.0f m", meters)
            } else {
                return String(format: "%.2f km", meters / 1000)
            }
        case .imperial:
            let feet = meters * 3.28084
            if feet < 5280 {
                return String(format: "%.0f ft", feet)
            } else {
                let miles = feet / 5280
                return String(format: "%.2f mi", miles)
            }
        }
    }

    // MARK: - Haversine Distance

    private func haversineDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let earthRadius: Double = 6371000 // meters

        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let deltaLat = (to.latitude - from.latitude) * .pi / 180
        let deltaLon = (to.longitude - from.longitude) * .pi / 180

        let a = sin(deltaLat / 2) * sin(deltaLat / 2) +
                cos(lat1) * cos(lat2) *
                sin(deltaLon / 2) * sin(deltaLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))

        return earthRadius * c
    }

    // MARK: - Bearing Formatting

    private func formatBearing(_ bearing: Double) -> String {
        // Use mils for MGRS (military) format, degrees otherwise
        if coordMode == .mgrs {
            let mils = bearing * (6400.0 / 360.0)
            return String(format: "%.0f mils", mils)
        } else {
            return String(format: "%.0f°", bearing)
        }
    }

    // MARK: - Bearing Calculation

    private func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let lon1 = from.longitude * .pi / 180
        let lon2 = to.longitude * .pi / 180

        let dLon = lon2 - lon1

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)

        var bearing = atan2(y, x) * 180 / .pi
        if bearing < 0 {
            bearing += 360
        }
        return bearing
    }
}

// MARK: - HUD Row

private struct HudRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 90, alignment: .leading)

            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Compact HUD

/// Compact single-line HUD showing just coordinates
public struct CompactHud: View {
    let position: CLLocationCoordinate2D?
    let coordMode: CoordMode

    public init(position: CLLocationCoordinate2D?, coordMode: CoordMode) {
        self.position = position
        self.coordMode = coordMode
    }

    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "location.fill")
                .font(.caption)
                .foregroundColor(.blue)

            Text(coordinateText)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
    }

    private var coordinateText: String {
        guard let pos = position else {
            return "No position"
        }
        return MapCoordinateUtils.formatCoordinate(lat: pos.latitude, lon: pos.longitude, mode: coordMode)
    }
}

// MARK: - Crosshair Overlay

/// Crosshair overlay for map center targeting
public struct CrosshairOverlay: View {
    var color: Color = .red
    var size: CGFloat = 40
    var lineWidth: CGFloat = 2

    public init(color: Color = .red, size: CGFloat = 40, lineWidth: CGFloat = 2) {
        self.color = color
        self.size = size
        self.lineWidth = lineWidth
    }

    public var body: some View {
        ZStack {
            // Vertical line
            Rectangle()
                .fill(color)
                .frame(width: lineWidth, height: size)

            // Horizontal line
            Rectangle()
                .fill(color)
                .frame(width: size, height: lineWidth)

            // Center dot
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)

            // Outer circle
            Circle()
                .stroke(color, lineWidth: lineWidth)
                .frame(width: size * 0.7, height: size * 0.7)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Compass Overlay

/// Compass overlay showing current heading
public struct CompassOverlay: View {
    let heading: Double // degrees, 0 = North
    var size: CGFloat = 50

    public init(heading: Double, size: CGFloat = 50) {
        self.heading = heading
        self.size = size
    }

    public var body: some View {
        ZStack {
            // Background
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: size, height: size)

            // Compass needle
            VStack(spacing: 0) {
                // North indicator
                Triangle()
                    .fill(.red)
                    .frame(width: 8, height: 12)

                Spacer()

                // South indicator
                Triangle()
                    .fill(.white)
                    .frame(width: 8, height: 12)
                    .rotationEffect(.degrees(180))
            }
            .frame(width: size * 0.3, height: size * 0.6)
            .rotationEffect(.degrees(-heading))

            // N label
            Text("N")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.red)
                .offset(y: -size * 0.35)
                .rotationEffect(.degrees(-heading))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Triangle Shape

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Scale Bar

/// Map scale bar overlay
public struct ScaleBar: View {
    let metersPerPoint: Double // meters per screen point at current zoom
    let unitSystem: UnitSystem

    public init(metersPerPoint: Double, unitSystem: UnitSystem = .metric) {
        self.metersPerPoint = metersPerPoint
        self.unitSystem = unitSystem
    }

    public var body: some View {
        HStack(spacing: 4) {
            Rectangle()
                .fill(Color.primary)
                .frame(width: barWidth, height: 2)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Color.primary)
                        .frame(width: 2, height: 8)
                }
                .overlay(alignment: .trailing) {
                    Rectangle()
                        .fill(Color.primary)
                        .frame(width: 2, height: 8)
                }

            Text(scaleText)
                .font(.caption2)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .cornerRadius(4)
    }

    private var barWidth: CGFloat {
        // Calculate a nice round scale bar width
        let targetWidth: CGFloat = 60
        return targetWidth
    }

    private var scaleText: String {
        let meters = metersPerPoint * Double(barWidth)
        switch unitSystem {
        case .metric:
            if meters < 1000 {
                return String(format: "%.0f m", meters)
            } else {
                return String(format: "%.1f km", meters / 1000)
            }
        case .imperial:
            let feet = meters * 3.28084
            if feet < 5280 {
                return String(format: "%.0f ft", feet)
            } else {
                return String(format: "%.1f mi", feet / 5280)
            }
        }
    }
}

// MARK: - Previews

#Preview("HUD Overlay") {
    ZStack {
        Color.gray.opacity(0.3)

        VStack {
            HudOverlay(
                myPosition: CLLocationCoordinate2D(latitude: 59.329323, longitude: 18.068581),
                crosshairPosition: CLLocationCoordinate2D(latitude: 59.335000, longitude: 18.075000),
                coordMode: .latLon,
                myAltitudeMeters: 42.5,
                crosshairAltitudeMeters: 38.2,
                unitSystem: .metric
            )
            .padding()

            Spacer()
        }
    }
}

#Preview("Compact HUD") {
    CompactHud(
        position: CLLocationCoordinate2D(latitude: 59.329323, longitude: 18.068581),
        coordMode: .latLon
    )
}

#Preview("Crosshair") {
    CrosshairOverlay()
}

#Preview("Compass") {
    CompassOverlay(heading: 45)
}

#Preview("Scale Bar") {
    ScaleBar(metersPerPoint: 10, unitSystem: .metric)
}
