import AppKit
import Foundation

let outputPath = CommandLine.arguments.dropFirst().first ?? "Assets/AppIcon/app-icon-master.png"
let outputURL = URL(fileURLWithPath: outputPath)
try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

let canvasSize = NSSize(width: 1024, height: 1024)
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(canvasSize.width),
    pixelsHigh: Int(canvasSize.height),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fputs("failed to create bitmap context\n", stderr)
    exit(1)
}

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    let red = CGFloat((hex >> 16) & 0xFF) / 255
    let green = CGFloat((hex >> 8) & 0xFF) / 255
    let blue = CGFloat(hex & 0xFF) / 255
    return NSColor(red: red, green: green, blue: blue, alpha: alpha)
}

func roundedRect(_ rect: CGRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func setShadow(blur: CGFloat, offsetY: CGFloat, color: NSColor?) {
    let shadow = NSShadow()
    shadow.shadowBlurRadius = blur
    shadow.shadowOffset = NSSize(width: 0, height: offsetY)
    shadow.shadowColor = color
    shadow.set()
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

NSColor.clear.setFill()
NSBezierPath(rect: CGRect(origin: .zero, size: canvasSize)).fill()

let outerRect = CGRect(x: 72, y: 72, width: 880, height: 880)
setShadow(blur: 44, offsetY: -22, color: color(0x000000, alpha: 0.32))
let outerPath = roundedRect(outerRect, radius: 188)
NSGradient(colors: [color(0x10151C), color(0x1A2530), color(0x263847)])?.draw(in: outerPath, angle: -90)
setShadow(blur: 0, offsetY: 0, color: nil)
color(0xFFFFFF, alpha: 0.08).setStroke()
outerPath.lineWidth = 4
outerPath.stroke()

let glowBlob = NSBezierPath(ovalIn: CGRect(x: 118, y: 488, width: 520, height: 340))
color(0x58C1FF, alpha: 0.12).setFill()
glowBlob.fill()

let menuBarRect = CGRect(x: 176, y: 654, width: 672, height: 136)
let menuBarPath = roundedRect(menuBarRect, radius: 68)
NSGradient(colors: [color(0xE8F7FF, alpha: 0.18), color(0xB7DFFF, alpha: 0.12)])?.draw(in: menuBarPath, angle: -90)
color(0xFFFFFF, alpha: 0.14).setStroke()
menuBarPath.lineWidth = 3
menuBarPath.stroke()

let dots: [CGRect] = [
    CGRect(x: 236, y: 700, width: 52, height: 38),
    CGRect(x: 308, y: 700, width: 52, height: 38),
    CGRect(x: 380, y: 700, width: 52, height: 38),
]
for rect in dots {
    let chip = roundedRect(rect, radius: 18)
    color(0x101821, alpha: 0.82).setFill()
    chip.fill()
}

let rightChip = roundedRect(CGRect(x: 654, y: 696, width: 132, height: 46), radius: 22)
color(0xF7FBFF, alpha: 0.24).setFill()
rightChip.fill()

let slash = NSBezierPath()
slash.move(to: CGPoint(x: 708, y: 820))
slash.line(to: CGPoint(x: 338, y: 450))
slash.lineWidth = 76
slash.lineCapStyle = .round
setShadow(blur: 28, offsetY: -8, color: color(0xFF5B3A, alpha: 0.30))
color(0xFF6B42).setStroke()
slash.stroke()
setShadow(blur: 0, offsetY: 0, color: nil)

let shelfRect = CGRect(x: 260, y: 254, width: 504, height: 244)
let shelfPath = roundedRect(shelfRect, radius: 98)
NSGradient(colors: [color(0xC6EDFF, alpha: 0.30), color(0x8FD8FF, alpha: 0.22)])?.draw(in: shelfPath, angle: -90)
color(0xFFFFFF, alpha: 0.16).setStroke()
shelfPath.lineWidth = 3
shelfPath.stroke()

let shelfInner = roundedRect(CGRect(x: 292, y: 288, width: 440, height: 176), radius: 78)
color(0x101821, alpha: 0.30).setFill()
shelfInner.fill()

let iconFrames: [CGRect] = [
    CGRect(x: 346, y: 332, width: 92, height: 92),
    CGRect(x: 468, y: 332, width: 92, height: 92),
    CGRect(x: 590, y: 332, width: 92, height: 92),
]
let iconColors: [UInt32] = [0x69D5FF, 0xF4C54C, 0x77F0C1]
for (index, rect) in iconFrames.enumerated() {
    let iconPath = roundedRect(rect, radius: 30)
    color(iconColors[index], alpha: 0.94).setFill()
    iconPath.fill()

    let inner = roundedRect(rect.insetBy(dx: 16, dy: 16), radius: 18)
    color(0x0F1720, alpha: 0.72).setFill()
    inner.fill()
}

let notch = roundedRect(CGRect(x: 420, y: 574, width: 184, height: 30), radius: 15)
color(0xD9F3FF, alpha: 0.16).setFill()
notch.fill()

NSGraphicsContext.restoreGraphicsState()

guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fputs("failed to encode png\n", stderr)
    exit(1)
}

try pngData.write(to: outputURL, options: .atomic)
print(outputURL.path)
