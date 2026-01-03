import SwiftUI

// MARK: - NATO Tactical Icons

/// Custom tactical icons for map pins and UI elements
/// Mirrors Android NatoIcons.kt implementation

// MARK: - Drone Pin Icon

/// Custom drone icon for "Drone observed" pin type
/// Quadcopter-style icon with center body and four rotors
public struct DronePinIcon: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let scale = min(rect.width, rect.height) / 24.0
        let offsetX = (rect.width - 24 * scale) / 2
        let offsetY = (rect.height - 24 * scale) / 2

        func x(_ val: CGFloat) -> CGFloat { offsetX + val * scale }
        func y(_ val: CGFloat) -> CGFloat { offsetY + val * scale }

        // Center body
        path.move(to: CGPoint(x: x(10), y: y(10)))
        path.addLine(to: CGPoint(x: x(14), y: y(10)))
        path.addLine(to: CGPoint(x: x(14), y: y(14)))
        path.addLine(to: CGPoint(x: x(10), y: y(14)))
        path.closeSubpath()

        // Horizontal arms
        path.move(to: CGPoint(x: x(6), y: y(11.25)))
        path.addLine(to: CGPoint(x: x(10), y: y(11.25)))
        path.addLine(to: CGPoint(x: x(10), y: y(12.75)))
        path.addLine(to: CGPoint(x: x(6), y: y(12.75)))
        path.closeSubpath()

        path.move(to: CGPoint(x: x(14), y: y(11.25)))
        path.addLine(to: CGPoint(x: x(18), y: y(11.25)))
        path.addLine(to: CGPoint(x: x(18), y: y(12.75)))
        path.addLine(to: CGPoint(x: x(14), y: y(12.75)))
        path.closeSubpath()

        // Vertical arms
        path.move(to: CGPoint(x: x(11.25), y: y(6)))
        path.addLine(to: CGPoint(x: x(12.75), y: y(6)))
        path.addLine(to: CGPoint(x: x(12.75), y: y(10)))
        path.addLine(to: CGPoint(x: x(11.25), y: y(10)))
        path.closeSubpath()

        path.move(to: CGPoint(x: x(11.25), y: y(14)))
        path.addLine(to: CGPoint(x: x(12.75), y: y(14)))
        path.addLine(to: CGPoint(x: x(12.75), y: y(18)))
        path.addLine(to: CGPoint(x: x(11.25), y: y(18)))
        path.closeSubpath()

        // Rotor "discs" (small squares at the four corners)
        path.move(to: CGPoint(x: x(4.5), y: y(4.5)))
        path.addLine(to: CGPoint(x: x(6), y: y(4.5)))
        path.addLine(to: CGPoint(x: x(6), y: y(6)))
        path.addLine(to: CGPoint(x: x(4.5), y: y(6)))
        path.closeSubpath()

        path.move(to: CGPoint(x: x(18), y: y(4.5)))
        path.addLine(to: CGPoint(x: x(19.5), y: y(4.5)))
        path.addLine(to: CGPoint(x: x(19.5), y: y(6)))
        path.addLine(to: CGPoint(x: x(18), y: y(6)))
        path.closeSubpath()

        path.move(to: CGPoint(x: x(4.5), y: y(18)))
        path.addLine(to: CGPoint(x: x(6), y: y(18)))
        path.addLine(to: CGPoint(x: x(6), y: y(19.5)))
        path.addLine(to: CGPoint(x: x(4.5), y: y(19.5)))
        path.closeSubpath()

        path.move(to: CGPoint(x: x(18), y: y(18)))
        path.addLine(to: CGPoint(x: x(19.5), y: y(18)))
        path.addLine(to: CGPoint(x: x(19.5), y: y(19.5)))
        path.addLine(to: CGPoint(x: x(18), y: y(19.5)))
        path.closeSubpath()

        return path
    }
}

// MARK: - Compass Needle Icon

/// Compass needle icon with red north and white south halves
public struct CompassNeedleIcon: View {
    public init() {}

    public var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let scale = size / 24.0
            let offsetX = (geometry.size.width - size) / 2
            let offsetY = (geometry.size.height - size) / 2

            ZStack {
                // North half (red)
                CompassNorthPath()
                    .fill(Color(red: 0.827, green: 0.184, blue: 0.184)) // #D32F2F
                    .frame(width: size, height: size)
                    .offset(x: offsetX, y: offsetY)

                // South half (white with outline)
                CompassSouthPath()
                    .fill(Color.white)
                    .frame(width: size, height: size)
                    .offset(x: offsetX, y: offsetY)

                CompassSouthPath()
                    .stroke(Color(white: 0.26), lineWidth: 0.5 * scale) // #424242
                    .frame(width: size, height: size)
                    .offset(x: offsetX, y: offsetY)

                // Center pivot circle
                Circle()
                    .fill(Color(white: 0.26)) // #424242
                    .frame(width: 4 * scale, height: 4 * scale)
                    .offset(x: offsetX + 10 * scale, y: offsetY + 10 * scale)
            }
        }
    }
}

/// North half of compass needle
private struct CompassNorthPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let scale = min(rect.width, rect.height) / 24.0
        let offsetX = (rect.width - 24 * scale) / 2
        let offsetY = (rect.height - 24 * scale) / 2

        func x(_ val: CGFloat) -> CGFloat { offsetX + val * scale }
        func y(_ val: CGFloat) -> CGFloat { offsetY + val * scale }

        // North half - pointing up
        path.move(to: CGPoint(x: x(12), y: y(2)))    // Top point
        path.addLine(to: CGPoint(x: x(15), y: y(12))) // Right middle
        path.addLine(to: CGPoint(x: x(12), y: y(10))) // Center notch
        path.addLine(to: CGPoint(x: x(9), y: y(12)))  // Left middle
        path.closeSubpath()

        return path
    }
}

/// South half of compass needle
private struct CompassSouthPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let scale = min(rect.width, rect.height) / 24.0
        let offsetX = (rect.width - 24 * scale) / 2
        let offsetY = (rect.height - 24 * scale) / 2

        func x(_ val: CGFloat) -> CGFloat { offsetX + val * scale }
        func y(_ val: CGFloat) -> CGFloat { offsetY + val * scale }

        // South half - pointing down
        path.move(to: CGPoint(x: x(12), y: y(22)))   // Bottom point
        path.addLine(to: CGPoint(x: x(9), y: y(12))) // Left middle
        path.addLine(to: CGPoint(x: x(12), y: y(14))) // Center notch
        path.addLine(to: CGPoint(x: x(15), y: y(12))) // Right middle
        path.closeSubpath()

        return path
    }
}

// MARK: - Tent Icon

/// Custom tent/cabin icon for Observation Post
public struct TentIcon: View {
    public init() {}

    public var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let scale = size / 24.0
            let offsetX = (geometry.size.width - size) / 2
            let offsetY = (geometry.size.height - size) / 2

            ZStack {
                // Tent roof (triangle)
                TentRoofPath()
                    .fill(Color.black)
                    .frame(width: size, height: size)
                    .offset(x: offsetX, y: offsetY)

                // Door opening (cut-out in white)
                TentDoorPath()
                    .fill(Color.white)
                    .frame(width: size, height: size)
                    .offset(x: offsetX, y: offsetY)

                // Ground line
                TentGroundPath()
                    .fill(Color.black)
                    .frame(width: size, height: size)
                    .offset(x: offsetX, y: offsetY)
            }
        }
    }
}

/// Tent roof triangle
private struct TentRoofPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let scale = min(rect.width, rect.height) / 24.0
        let offsetX = (rect.width - 24 * scale) / 2
        let offsetY = (rect.height - 24 * scale) / 2

        func x(_ val: CGFloat) -> CGFloat { offsetX + val * scale }
        func y(_ val: CGFloat) -> CGFloat { offsetY + val * scale }

        path.move(to: CGPoint(x: x(12), y: y(4)))
        path.addLine(to: CGPoint(x: x(21), y: y(18)))
        path.addLine(to: CGPoint(x: x(3), y: y(18)))
        path.closeSubpath()

        return path
    }
}

/// Tent door triangle
private struct TentDoorPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let scale = min(rect.width, rect.height) / 24.0
        let offsetX = (rect.width - 24 * scale) / 2
        let offsetY = (rect.height - 24 * scale) / 2

        func x(_ val: CGFloat) -> CGFloat { offsetX + val * scale }
        func y(_ val: CGFloat) -> CGFloat { offsetY + val * scale }

        path.move(to: CGPoint(x: x(12), y: y(10)))
        path.addLine(to: CGPoint(x: x(15), y: y(18)))
        path.addLine(to: CGPoint(x: x(9), y: y(18)))
        path.closeSubpath()

        return path
    }
}

/// Tent ground line
private struct TentGroundPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let scale = min(rect.width, rect.height) / 24.0
        let offsetX = (rect.width - 24 * scale) / 2
        let offsetY = (rect.height - 24 * scale) / 2

        func x(_ val: CGFloat) -> CGFloat { offsetX + val * scale }
        func y(_ val: CGFloat) -> CGFloat { offsetY + val * scale }

        path.move(to: CGPoint(x: x(2), y: y(18)))
        path.addLine(to: CGPoint(x: x(22), y: y(18)))
        path.addLine(to: CGPoint(x: x(22), y: y(20)))
        path.addLine(to: CGPoint(x: x(2), y: y(20)))
        path.closeSubpath()

        return path
    }
}

// MARK: - Crosshair Icon

/// Simple crosshair icon for map center indicator
public struct CrosshairIcon: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let size = min(rect.width, rect.height)
        let gap = size * 0.15
        let armLength = size * 0.35

        // Top arm
        path.move(to: CGPoint(x: center.x, y: center.y - gap))
        path.addLine(to: CGPoint(x: center.x, y: center.y - gap - armLength))

        // Bottom arm
        path.move(to: CGPoint(x: center.x, y: center.y + gap))
        path.addLine(to: CGPoint(x: center.x, y: center.y + gap + armLength))

        // Left arm
        path.move(to: CGPoint(x: center.x - gap, y: center.y))
        path.addLine(to: CGPoint(x: center.x - gap - armLength, y: center.y))

        // Right arm
        path.move(to: CGPoint(x: center.x + gap, y: center.y))
        path.addLine(to: CGPoint(x: center.x + gap + armLength, y: center.y))

        return path
    }
}

// MARK: - NATO Symbology Helper

/// Affiliation types for NATO symbols
public enum NATOAffiliation: String, CaseIterable {
    case friendly = "FRIENDLY"
    case hostile = "HOSTILE"
    case neutral = "NEUTRAL"
    case unknown = "UNKNOWN"

    public var frameColor: Color {
        switch self {
        case .friendly: return Color(red: 0.0, green: 0.6, blue: 1.0) // Blue
        case .hostile: return Color(red: 1.0, green: 0.2, blue: 0.2)  // Red
        case .neutral: return Color(red: 0.0, green: 0.8, blue: 0.4)  // Green
        case .unknown: return Color(red: 1.0, green: 0.8, blue: 0.0)  // Yellow
        }
    }

    public var fillColor: Color {
        frameColor.opacity(0.3)
    }
}

/// NATO symbol shapes for unit representation
public enum NATOSymbolShape: String, CaseIterable {
    case ground = "GROUND"        // Rectangle
    case air = "AIR"              // Semicircle (arc up)
    case naval = "NAVAL"          // Ellipse
    case subsurface = "SUBSURFACE" // Semicircle (arc down)

    /// Get the shape path for this symbol type
    public func path(in rect: CGRect) -> Path {
        var path = Path()

        switch self {
        case .ground:
            // Rectangle
            path.addRect(rect.insetBy(dx: rect.width * 0.1, dy: rect.height * 0.15))

        case .air:
            // Semicircle arc upward
            let inset = rect.insetBy(dx: rect.width * 0.1, dy: rect.height * 0.1)
            path.addArc(
                center: CGPoint(x: inset.midX, y: inset.maxY),
                radius: inset.width / 2,
                startAngle: .degrees(180),
                endAngle: .degrees(0),
                clockwise: false
            )

        case .naval:
            // Ellipse
            path.addEllipse(in: rect.insetBy(dx: rect.width * 0.1, dy: rect.height * 0.15))

        case .subsurface:
            // Semicircle arc downward
            let inset = rect.insetBy(dx: rect.width * 0.1, dy: rect.height * 0.1)
            path.addArc(
                center: CGPoint(x: inset.midX, y: inset.minY),
                radius: inset.width / 2,
                startAngle: .degrees(0),
                endAngle: .degrees(180),
                clockwise: false
            )
        }

        return path
    }
}

// MARK: - NATO Symbol View

/// A view that renders a NATO military symbol
public struct NATOSymbolView: View {
    public let affiliation: NATOAffiliation
    public let shape: NATOSymbolShape
    public let icon: String? // SF Symbol name or nil

    public init(
        affiliation: NATOAffiliation,
        shape: NATOSymbolShape = .ground,
        icon: String? = nil
    ) {
        self.affiliation = affiliation
        self.shape = shape
        self.icon = icon
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Fill
                shape.path(in: CGRect(origin: .zero, size: geometry.size))
                    .fill(affiliation.fillColor)

                // Frame
                shape.path(in: CGRect(origin: .zero, size: geometry.size))
                    .stroke(affiliation.frameColor, lineWidth: 2)

                // Icon (if provided)
                if let iconName = icon {
                    Image(systemName: iconName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geometry.size.width * 0.4, height: geometry.size.height * 0.4)
                        .foregroundColor(affiliation.frameColor)
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct NatoIcons_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                DronePinIcon()
                    .fill(Color.black)
                    .frame(width: 48, height: 48)

                CompassNeedleIcon()
                    .frame(width: 48, height: 48)

                TentIcon()
                    .frame(width: 48, height: 48)
            }

            HStack(spacing: 20) {
                CrosshairIcon()
                    .stroke(Color.red, lineWidth: 2)
                    .frame(width: 48, height: 48)

                NATOSymbolView(affiliation: .friendly, shape: .ground, icon: "person.fill")
                    .frame(width: 48, height: 48)

                NATOSymbolView(affiliation: .hostile, shape: .ground)
                    .frame(width: 48, height: 48)
            }
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
