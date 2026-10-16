// Render the existing Pluck mark as native vector artwork at every Mac icon size.
import AppKit
import Foundation

let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
var images: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let transform = NSAffineTransform()
        transform.scale(by: CGFloat(pixels) / 32)
        transform.concat()
        // Inset the rounded tile to follow the standard macOS icon canvas.
        NSColor(calibratedRed: 34/255, green: 77/255, blue: 224/255, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 2, y: 2, width: 28, height: 28), xRadius: 6.5, yRadius: 6.5).fill()
        NSColor.white.setStroke()
        let marks = NSBezierPath()
        marks.lineWidth = 1.8
        for path in [[(12.0, 9.0), (9.0, 9.0), (9.0, 12.0)],
                     [(20.0, 9.0), (23.0, 9.0), (23.0, 12.0)],
                     [(9.0, 20.0), (9.0, 23.0), (12.0, 23.0)],
                     [(23.0, 20.0), (23.0, 23.0), (20.0, 23.0)]] {
            marks.move(to: NSPoint(x: path[0].0, y: path[0].1))
            for point in path.dropFirst() { marks.line(to: NSPoint(x: point.0, y: point.1)) }
        }
        marks.stroke()
        NSColor.white.setFill()
        NSBezierPath(ovalIn: NSRect(x: 14, y: 14, width: 4, height: 4)).fill()
        NSGraphicsContext.restoreGraphicsState()
        let filename = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(filename))
        images.append(["idiom": "mac", "size": "\(points)x\(points)", "scale": "\(scale)x", "filename": filename])
    }
}
let catalog: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: catalog, options: [.prettyPrinted, .sortedKeys])
    .write(to: output.appendingPathComponent("Contents.json"))
