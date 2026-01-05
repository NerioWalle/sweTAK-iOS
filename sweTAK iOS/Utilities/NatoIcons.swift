import SwiftUI
import UIKit

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
    public var color: Color = .primary
    public var backgroundColor: Color = Color(.systemBackground)

    public init(color: Color = .primary, backgroundColor: Color = Color(.systemBackground)) {
        self.color = color
        self.backgroundColor = backgroundColor
    }

    public var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let offsetX = (geometry.size.width - size) / 2
            let offsetY = (geometry.size.height - size) / 2

            ZStack {
                // Tent roof (triangle)
                TentRoofPath()
                    .fill(color)
                    .frame(width: size, height: size)
                    .offset(x: offsetX, y: offsetY)

                // Door opening (cut-out)
                TentDoorPath()
                    .fill(backgroundColor)
                    .frame(width: size, height: size)
                    .offset(x: offsetX, y: offsetY)

                // Ground line
                TentGroundPath()
                    .fill(color)
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

// MARK: - IFS/Artillery Missile Icon

/// Custom missile/artillery icon for IFS form type
public struct IFSMissileIcon: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let scale = min(rect.width, rect.height) / 24.0
        let offsetX = (rect.width - 24 * scale) / 2
        let offsetY = (rect.height - 24 * scale) / 2

        func x(_ val: CGFloat) -> CGFloat { offsetX + val * scale }
        func y(_ val: CGFloat) -> CGFloat { offsetY + val * scale }

        // Missile/artillery shell shape
        path.move(to: CGPoint(x: x(12), y: y(2)))      // Tip
        path.addLine(to: CGPoint(x: x(15), y: y(8)))   // Right shoulder
        path.addLine(to: CGPoint(x: x(15), y: y(18)))  // Right side
        path.addLine(to: CGPoint(x: x(17), y: y(22)))  // Right fin
        path.addLine(to: CGPoint(x: x(7), y: y(22)))   // Left fin
        path.addLine(to: CGPoint(x: x(9), y: y(18)))   // Left side
        path.addLine(to: CGPoint(x: x(9), y: y(8)))    // Left shoulder
        path.closeSubpath()

        return path
    }
}

// MARK: - Military Tech/Medal Icon

/// Military medal/star icon for Artillery type (matches Android MilitaryTech)
public struct MilitaryTechIcon: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let scale = min(rect.width, rect.height) / 24.0
        let offsetX = (rect.width - 24 * scale) / 2
        let offsetY = (rect.height - 24 * scale) / 2

        let cx = offsetX + 12 * scale
        let cy = offsetY + 9 * scale

        // 5-pointed star
        let outerRadius = 7 * scale
        let innerRadius = 3 * scale

        for i in 0..<10 {
            let radius = i % 2 == 0 ? outerRadius : innerRadius
            let angle = (Double(i) * 36.0 - 90.0) * .pi / 180.0
            let x = cx + CGFloat(cos(angle)) * radius
            let y = cy + CGFloat(sin(angle)) * radius

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()

        // Medal ribbon
        path.addRect(CGRect(
            x: offsetX + 9 * scale,
            y: offsetY + 16 * scale,
            width: 6 * scale,
            height: 5 * scale
        ))

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

// MARK: - MyLocation Icon (matches Android Icons.Filled.MyLocation)

/// Crosshair-style location icon matching Android's MyLocation Material icon
/// Shows a circle with a dot in center and four pointing segments
public struct MyLocationIcon: View {
    public var size: CGFloat = 24
    public var color: Color = .primary

    public init(size: CGFloat = 24, color: Color = .primary) {
        self.size = size
        self.color = color
    }

    public var body: some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let scale = min(canvasSize.width, canvasSize.height) / 24.0

            // Outer circle (ring)
            let outerRadius = 9 * scale
            let ringWidth = 2 * scale
            var outerRing = Path()
            outerRing.addArc(center: center, radius: outerRadius, startAngle: .zero, endAngle: .degrees(360), clockwise: false)
            context.stroke(outerRing, with: .color(color), lineWidth: ringWidth)

            // Center dot
            let dotRadius = 3 * scale
            var centerDot = Path()
            centerDot.addArc(center: center, radius: dotRadius, startAngle: .zero, endAngle: .degrees(360), clockwise: false)
            context.fill(centerDot, with: .color(color))

            // Four crosshair arms extending outward from the ring
            let armLength = 3 * scale
            let armWidth = 2 * scale
            let gapFromCenter = outerRadius + ringWidth / 2

            // Top arm
            var topArm = Path()
            topArm.addRect(CGRect(
                x: center.x - armWidth / 2,
                y: center.y - gapFromCenter - armLength,
                width: armWidth,
                height: armLength
            ))
            context.fill(topArm, with: .color(color))

            // Bottom arm
            var bottomArm = Path()
            bottomArm.addRect(CGRect(
                x: center.x - armWidth / 2,
                y: center.y + gapFromCenter,
                width: armWidth,
                height: armLength
            ))
            context.fill(bottomArm, with: .color(color))

            // Left arm
            var leftArm = Path()
            leftArm.addRect(CGRect(
                x: center.x - gapFromCenter - armLength,
                y: center.y - armWidth / 2,
                width: armLength,
                height: armWidth
            ))
            context.fill(leftArm, with: .color(color))

            // Right arm
            var rightArm = Path()
            rightArm.addRect(CGRect(
                x: center.x + gapFromCenter,
                y: center.y - armWidth / 2,
                width: armLength,
                height: armWidth
            ))
            context.fill(rightArm, with: .color(color))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Video Recorder Style Record Button (matches Android)

/// Recording button matching Android's video recorder style
/// White ring around edge, red circle when not recording, red rounded square when recording
public struct RecordButtonIcon: View {
    public var isRecording: Bool
    public var size: CGFloat = 56

    public init(isRecording: Bool = false, size: CGFloat = 56) {
        self.isRecording = isRecording
        self.size = size
    }

    public var body: some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let outerRadius = min(canvasSize.width, canvasSize.height) / 2
            let strokeWidth: CGFloat = 4

            // Outer white ring
            var outerRing = Path()
            outerRing.addArc(center: center, radius: outerRadius - strokeWidth / 2, startAngle: .zero, endAngle: .degrees(360), clockwise: false)
            context.stroke(outerRing, with: .color(.white), lineWidth: strokeWidth)

            if isRecording {
                // Recording: Red rounded square (stop button)
                let squareSize = outerRadius * 0.9
                let cornerRadius: CGFloat = 4
                let squareRect = CGRect(
                    x: center.x - squareSize / 2,
                    y: center.y - squareSize / 2,
                    width: squareSize,
                    height: squareSize
                )
                var squarePath = Path(roundedRect: squareRect, cornerRadius: cornerRadius)
                context.fill(squarePath, with: .color(.red))
            } else {
                // Not recording: Red circle
                let innerRadius = outerRadius * 0.7
                var innerCircle = Path()
                innerCircle.addArc(center: center, radius: innerRadius, startAngle: .zero, endAngle: .degrees(360), clockwise: false)
                context.fill(innerCircle, with: .color(.red))
            }
        }
        .frame(width: size, height: size)
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

// MARK: - NATO Pin Icon View

/// Unified view for displaying any NATO pin type icon
/// Matches Android's pin icon rendering
public struct NatoPinIconView: View {
    public let pinType: NatoType
    public var size: CGFloat = 20
    public var color: Color = .primary
    public var backgroundColor: Color = .clear

    public init(pinType: NatoType, size: CGFloat = 20, color: Color = .primary, backgroundColor: Color = .clear) {
        self.pinType = pinType
        self.size = size
        self.color = color
        self.backgroundColor = backgroundColor
    }

    public var body: some View {
        Group {
            switch pinType {
            case .infantry:
                Image(systemName: "flag.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(color)

            case .intelligence:
                Image(systemName: "eye.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(color)

            case .surveillance:
                Image(systemName: "sensor.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(color)

            case .artillery:
                MilitaryTechIcon()
                    .fill(color)

            case .marine:
                Image(systemName: "anchor.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(color)

            case .droneObserved:
                DronePinIcon()
                    .fill(color)

            case .op:
                TentIcon(color: color)

            case .photo:
                Image(systemName: "camera.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(color)

            case .form7S:
                Image(systemName: "doc.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(color)

            case .formIFS:
                IFSMissileIcon()
                    .fill(color)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - NATO Pin Marker View

/// Complete pin marker view matching Android's circular pin rendering
public struct NatoPinMarkerView: View {
    public let pinType: NatoType
    public var markerSize: CGFloat = 36
    public var iconSize: CGFloat = 24

    public init(pinType: NatoType, markerSize: CGFloat = 36, iconSize: CGFloat = 24) {
        self.pinType = pinType
        self.markerSize = markerSize
        self.iconSize = iconSize
    }

    public var body: some View {
        ZStack {
            // Circular background with transparency
            Circle()
                .fill(Color(.systemBackground).opacity(0.85))
                .frame(width: markerSize, height: markerSize)

            // Shadow for depth
            Circle()
                .stroke(Color.black.opacity(0.2), lineWidth: 1)
                .frame(width: markerSize, height: markerSize)

            // Icon
            if pinType == .form7S || pinType == .formIFS {
                // Form pins: smaller icon with text label
                VStack(spacing: 0) {
                    NatoPinIconView(
                        pinType: pinType,
                        size: 14,
                        color: markerColor,
                        backgroundColor: Color(.systemBackground).opacity(0.85)
                    )
                    Text(pinType == .form7S ? "7S" : "IFS")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(markerColor)
                }
            } else {
                // Standard pins: icon only
                NatoPinIconView(
                    pinType: pinType,
                    size: iconSize,
                    color: markerColor,
                    backgroundColor: Color(.systemBackground).opacity(0.85)
                )
            }
        }
    }

    private var markerColor: Color {
        switch pinType {
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

// MARK: - UIImage Generation for Map Annotations

extension NatoPinMarkerView {
    /// Convert the SwiftUI view to a UIImage for use in MKAnnotationView
    @MainActor
    func asUIImage() -> UIImage {
        // Use ImageRenderer for iOS 16+
        let renderer = ImageRenderer(content: self.frame(width: markerSize, height: markerSize))
        renderer.scale = UIScreen.main.scale

        if let uiImage = renderer.uiImage {
            return uiImage
        }

        // Fallback: create a simple colored circle with SF Symbol
        let size = CGSize(width: markerSize, height: markerSize)
        let renderer2 = UIGraphicsImageRenderer(size: size)
        return renderer2.image { context in
            // Draw circle background
            UIColor.systemBackground.withAlphaComponent(0.85).setFill()
            context.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))

            // Draw border
            UIColor.black.withAlphaComponent(0.2).setStroke()
            context.cgContext.setLineWidth(1)
            context.cgContext.strokeEllipse(in: CGRect(origin: .zero, size: size).insetBy(dx: 0.5, dy: 0.5))
        }
    }
}

/// Cache for pre-rendered pin marker images
public class PinMarkerImageCache {
    public static let shared = PinMarkerImageCache()

    private var cache: [NatoType: UIImage] = [:]
    private let markerSize: CGFloat = 36

    private init() {}

    @MainActor
    public func image(for pinType: NatoType) -> UIImage {
        if let cached = cache[pinType] {
            return cached
        }

        let image = createMarkerImage(for: pinType)
        cache[pinType] = image
        return image
    }

    public func clearCache() {
        cache.removeAll()
    }

    /// Create marker image using Core Graphics for reliability
    private func createMarkerImage(for pinType: NatoType) -> UIImage {
        let size = CGSize(width: markerSize, height: markerSize)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            let ctx = context.cgContext

            // Draw circular background
            UIColor.systemBackground.withAlphaComponent(0.9).setFill()
            ctx.fillEllipse(in: rect.insetBy(dx: 1, dy: 1))

            // Draw border
            markerColor(for: pinType).withAlphaComponent(0.5).setStroke()
            ctx.setLineWidth(2)
            ctx.strokeEllipse(in: rect.insetBy(dx: 2, dy: 2))

            // Draw icon
            let iconRect = rect.insetBy(dx: 8, dy: 8)
            let iconColor = markerColor(for: pinType)

            if let sfSymbol = sfSymbolName(for: pinType) {
                // Use SF Symbol with palette colors for reliable tinting
                let sizeConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
                let colorConfig = UIImage.SymbolConfiguration(paletteColors: [iconColor])
                let config = sizeConfig.applying(colorConfig)
                if let symbolImage = UIImage(systemName: sfSymbol, withConfiguration: config) {
                    let symbolSize = symbolImage.size
                    let x = (size.width - symbolSize.width) / 2
                    let y = (size.height - symbolSize.height) / 2
                    symbolImage.draw(at: CGPoint(x: x, y: y))
                }
            } else {
                // Draw custom shape
                drawCustomIcon(for: pinType, in: iconRect, color: iconColor, context: ctx)
            }
        }
    }

    private func sfSymbolName(for pinType: NatoType) -> String? {
        switch pinType {
        case .infantry: return "flag.fill"
        case .intelligence: return "eye.fill"
        case .surveillance: return "sensor.fill"
        case .marine: return "anchor.fill"
        case .photo: return "camera.fill"
        case .form7S: return "doc.fill"
        case .artillery, .droneObserved, .op, .formIFS:
            return nil // Custom icons
        }
    }

    private func drawCustomIcon(for pinType: NatoType, in rect: CGRect, color: UIColor, context: CGContext) {
        color.setFill()
        color.setStroke()

        let scale = min(rect.width, rect.height) / 24.0
        let offsetX = rect.minX + (rect.width - 24 * scale) / 2
        let offsetY = rect.minY + (rect.height - 24 * scale) / 2

        func x(_ val: CGFloat) -> CGFloat { offsetX + val * scale }
        func y(_ val: CGFloat) -> CGFloat { offsetY + val * scale }

        switch pinType {
        case .droneObserved:
            // Quadcopter drone
            let path = UIBezierPath()
            // Center body
            path.append(UIBezierPath(rect: CGRect(x: x(10), y: y(10), width: 4 * scale, height: 4 * scale)))
            // Arms
            path.append(UIBezierPath(rect: CGRect(x: x(6), y: y(11), width: 4 * scale, height: 2 * scale)))
            path.append(UIBezierPath(rect: CGRect(x: x(14), y: y(11), width: 4 * scale, height: 2 * scale)))
            path.append(UIBezierPath(rect: CGRect(x: x(11), y: y(6), width: 2 * scale, height: 4 * scale)))
            path.append(UIBezierPath(rect: CGRect(x: x(11), y: y(14), width: 2 * scale, height: 4 * scale)))
            // Rotors
            path.append(UIBezierPath(ovalIn: CGRect(x: x(4), y: y(4), width: 4 * scale, height: 4 * scale)))
            path.append(UIBezierPath(ovalIn: CGRect(x: x(16), y: y(4), width: 4 * scale, height: 4 * scale)))
            path.append(UIBezierPath(ovalIn: CGRect(x: x(4), y: y(16), width: 4 * scale, height: 4 * scale)))
            path.append(UIBezierPath(ovalIn: CGRect(x: x(16), y: y(16), width: 4 * scale, height: 4 * scale)))
            path.fill()

        case .op:
            // Tent
            let path = UIBezierPath()
            path.move(to: CGPoint(x: x(12), y: y(4)))
            path.addLine(to: CGPoint(x: x(21), y: y(18)))
            path.addLine(to: CGPoint(x: x(3), y: y(18)))
            path.close()
            path.fill()
            // Ground
            UIBezierPath(rect: CGRect(x: x(2), y: y(18), width: 20 * scale, height: 2 * scale)).fill()
            // Door cutout
            UIColor.systemBackground.setFill()
            let door = UIBezierPath()
            door.move(to: CGPoint(x: x(12), y: y(10)))
            door.addLine(to: CGPoint(x: x(15), y: y(18)))
            door.addLine(to: CGPoint(x: x(9), y: y(18)))
            door.close()
            door.fill()

        case .artillery:
            // Star/medal
            let cx = x(12)
            let cy = y(10)
            let outerR = 6 * scale
            let innerR = 2.5 * scale
            let star = UIBezierPath()
            for i in 0..<10 {
                let r = i % 2 == 0 ? outerR : innerR
                let angle = (CGFloat(i) * 36.0 - 90.0) * .pi / 180.0
                let px = cx + cos(angle) * r
                let py = cy + sin(angle) * r
                if i == 0 { star.move(to: CGPoint(x: px, y: py)) }
                else { star.addLine(to: CGPoint(x: px, y: py)) }
            }
            star.close()
            star.fill()
            // Ribbon
            UIBezierPath(rect: CGRect(x: x(9), y: y(16), width: 6 * scale, height: 4 * scale)).fill()

        case .formIFS:
            // Missile
            let path = UIBezierPath()
            path.move(to: CGPoint(x: x(12), y: y(3)))
            path.addLine(to: CGPoint(x: x(15), y: y(8)))
            path.addLine(to: CGPoint(x: x(15), y: y(17)))
            path.addLine(to: CGPoint(x: x(17), y: y(21)))
            path.addLine(to: CGPoint(x: x(7), y: y(21)))
            path.addLine(to: CGPoint(x: x(9), y: y(17)))
            path.addLine(to: CGPoint(x: x(9), y: y(8)))
            path.close()
            path.fill()

        default:
            break
        }
    }

    private func markerColor(for pinType: NatoType) -> UIColor {
        switch pinType {
        case .infantry, .marine:
            return .systemRed
        case .intelligence, .surveillance, .droneObserved:
            return .systemOrange
        case .artillery:
            return .systemPurple
        case .op:
            return .systemGreen
        case .photo:
            return .systemBlue
        case .form7S, .formIFS:
            return .systemGray
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
