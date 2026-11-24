// Draws the original My Calc icon in code and writes the .icns family.
// A pocket calculator in the My Suite style: one glossy object in three-quarter view with a
// thick blue body, a cream display with "My" in navy and a grid of glossy keys with an orange
// "=" key, on a transparent background. The artwork fills the canvas edge to edge.
// Usage: swift Tools/icon.swift Resources/MyCalc.icns [preview.png]
import AppKit
import CoreText

let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
    FileHandle.standardError.write("usage: icon.swift output.icns [preview.png]\n".data(using: .utf8)!)
    exit(2)
}

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: alpha)
}

let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

func fill(_ context: CGContext, _ path: CGPath, _ stops: [(UInt32, CGFloat, CGFloat)], from: CGPoint, to: CGPoint) {
    context.saveGState()
    context.addPath(path); context.clip()
    let gradient = CGGradient(colorsSpace: sRGB, colors: stops.map { rgb($0.0, $0.1) } as CFArray, locations: stops.map { $0.2 })!
    context.drawLinearGradient(gradient, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    context.restoreGState()
}

// Core Graphics shadows ignore the CTM, so they are scaled by hand for each output size.
var shadowScale: CGFloat = 1
func shadow(_ context: CGContext, x: CGFloat, y: CGFloat, blur: CGFloat, _ tint: CGColor) {
    context.setShadow(offset: CGSize(width: x * shadowScale, height: y * shadowScale), blur: blur * shadowScale, color: tint)
}

// The calculator is drawn on a flat face (640 × 800, y down) and leaned back in three-quarter
// view, like the My Notepad pad, the My Explorer folder and the My Paint palette.
let lean = CGAffineTransform(a: 1, b: 0.10, c: -0.30, d: 1, tx: 0, ty: 0)
let edgeDepth = 34

let face = CGRect(x: 0, y: 0, width: 640, height: 800)

func rounded(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func body() -> CGPath { rounded(face, 96) }

func lettering(_ text: String, size: CGFloat, centre: CGFloat, baseline: CGFloat) -> CGPath {
    let font = NSFont.systemFont(ofSize: size, weight: .black)
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [.font: font, .kern: -size * 0.02]))
    let path = CGMutablePath()
    for run in CTLineGetGlyphRuns(line) as! [CTRun] {
        let count = CTRunGetGlyphCount(run)
        var glyphs = [CGGlyph](repeating: 0, count: count), positions = [CGPoint](repeating: .zero, count: count)
        CTRunGetGlyphs(run, CFRange(), &glyphs); CTRunGetPositions(run, CFRange(), &positions)
        let runFont = (CTRunGetAttributes(run) as NSDictionary)[kCTFontAttributeName as String] as! CTFont
        for index in 0..<count {
            // Glyph outlines are y-up; flip them into the y-down face.
            var flip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: positions[index].x, ty: baseline)
            if let glyph = CTFontCreatePathForGlyph(runFont, glyphs[index], &flip) { path.addPath(glyph) }
        }
    }
    var move = CGAffineTransform(translationX: centre - path.boundingBoxOfPath.midX, y: 0)
    return path.copy(using: &move) ?? path
}

/// The colours of one key: top light, face, lower face, the darker skirt below it, and the symbol.
struct KeyStyle {
    let light: UInt32, base: UInt32, dark: UInt32, skirt: UInt32, ink: UInt32
}

let creamKey = KeyStyle(light: 0xFFFFFF, base: 0xFFFBF0, dark: 0xE9DDC2, skirt: 0xB3A47F, ink: 0x0B1E5B)
let blueKey = KeyStyle(light: 0xE4EEFF, base: 0xB7D2FF, dark: 0x86B0FA, skirt: 0x4A78CF, ink: 0x0B1E5B)
let orangeKey = KeyStyle(light: 0xFFD08A, base: 0xFF9A2E, dark: 0xEE6A0C, skirt: 0xA9440A, ink: 0xFFFFFF)

enum Symbol { case none, plus, minus, times, divide, equals }

/// One key: a glossy cap standing on a darker skirt, with an optional symbol stroked on it.
func key(_ context: CGContext, _ rect: CGRect, _ style: KeyStyle, _ symbol: Symbol, detail: Bool) {
    let radius = min(rect.width, rect.height) * 0.26
    let lift: CGFloat = detail ? 12 : 16
    let cap = rounded(rect, radius)
    let skirt = rounded(rect.offsetBy(dx: 0, dy: lift), radius)

    context.saveGState()
    shadow(context, x: 5, y: -9, blur: 12, rgb(0x061340, 0.50))
    context.addPath(skirt); context.setFillColor(rgb(style.skirt)); context.fillPath()
    context.restoreGState()
    fill(context, cap, [(style.light, 1, 0), (style.base, 1, 0.35), (style.dark, 1, 1)],
         from: CGPoint(x: rect.minX, y: rect.minY), to: CGPoint(x: rect.midX, y: rect.maxY))

    guard detail else { return }
    // A soft sheen across the upper half of the cap.
    let sheen = rounded(CGRect(x: rect.minX + 9, y: rect.minY + 7, width: rect.width - 18, height: rect.height * 0.40), radius * 0.7)
    fill(context, sheen, [(0xFFFFFF, 0.70, 0), (0xFFFFFF, 0.0, 1)],
         from: CGPoint(x: 0, y: rect.minY + 7), to: CGPoint(x: 0, y: rect.minY + 7 + rect.height * 0.40))

    let centre = CGPoint(x: rect.midX, y: rect.midY + 2), arm = rect.height * 0.25
    context.saveGState()
    context.setStrokeColor(rgb(style.ink)); context.setFillColor(rgb(style.ink))
    context.setLineWidth(13); context.setLineCap(.round)
    switch symbol {
    case .none:
        break
    case .plus:
        context.move(to: CGPoint(x: centre.x - arm, y: centre.y)); context.addLine(to: CGPoint(x: centre.x + arm, y: centre.y))
        context.move(to: CGPoint(x: centre.x, y: centre.y - arm)); context.addLine(to: CGPoint(x: centre.x, y: centre.y + arm))
    case .minus:
        context.move(to: CGPoint(x: centre.x - arm, y: centre.y)); context.addLine(to: CGPoint(x: centre.x + arm, y: centre.y))
    case .times:
        let reach = arm * 0.78
        context.move(to: CGPoint(x: centre.x - reach, y: centre.y - reach)); context.addLine(to: CGPoint(x: centre.x + reach, y: centre.y + reach))
        context.move(to: CGPoint(x: centre.x + reach, y: centre.y - reach)); context.addLine(to: CGPoint(x: centre.x - reach, y: centre.y + reach))
    case .divide:
        context.move(to: CGPoint(x: centre.x - arm, y: centre.y)); context.addLine(to: CGPoint(x: centre.x + arm, y: centre.y))
        for side in [CGFloat(-1), 1] {
            context.fillEllipse(in: CGRect(x: centre.x - 8, y: centre.y + side * arm * 0.84 - 8, width: 16, height: 16))
        }
    case .equals:
        for side in [CGFloat(-1), 1] {
            context.move(to: CGPoint(x: centre.x - arm, y: centre.y + side * arm * 0.46))
            context.addLine(to: CGPoint(x: centre.x + arm, y: centre.y + side * arm * 0.46))
        }
    }
    context.strokePath()
    context.restoreGState()
}

func drawCalculator(_ context: CGContext, detail: Bool) {
    let shell = body()
    fill(context, shell, [(0x5B97FF, 1, 0), (0x2468EC, 1, 0.45), (0x1243B4, 1, 1)], from: CGPoint(x: 80, y: 0), to: CGPoint(x: 520, y: 800))

    // A light line along the outer edge of the body.
    context.saveGState()
    context.addPath(shell); context.clip()
    context.setLineWidth(14)
    context.setStrokeColor(rgb(0xBFD6FF, 0.75))
    context.addPath(shell); context.strokePath()
    context.restoreGState()

    // Cream display, sunk a little into the body.
    let window = detail ? CGRect(x: 56, y: 58, width: 528, height: 226) : CGRect(x: 44, y: 46, width: 552, height: 318)
    let bezel = rounded(window.insetBy(dx: -10, dy: -10), 48)
    context.addPath(bezel); context.setFillColor(rgb(0x0B2F8A, 0.85)); context.fillPath()
    let display = rounded(window, 40)
    fill(context, display, [(0xFFFBF0, 1, 0), (0xF6EEDB, 1, 0.6), (0xE9DDC2, 1, 1)],
         from: CGPoint(x: window.minX + 80, y: window.minY), to: CGPoint(x: window.maxX - 80, y: window.maxY))
    // The body's shade along the top and left of the display.
    context.saveGState()
    context.addPath(display); context.clip()
    context.setLineWidth(26)
    context.setStrokeColor(rgb(0x0A1E5C, 0.22))
    context.addPath(rounded(window.offsetBy(dx: 7, dy: 9), 40)); context.strokePath()
    context.restoreGState()

    // "My", as on the other icons of the suite, where the digits would be.
    let size: CGFloat = detail ? 200 : 268
    let baseline = window.midY + size * 0.27
    context.addPath(lettering("My", size: size, centre: window.midX, baseline: baseline))
    context.setFillColor(rgb(0x0B1E5B)); context.fillPath()

    // Keys: four columns by four rows, or three by two bigger ones at small sizes.
    let columns = detail ? 4 : 3, rows = detail ? 4 : 2
    let pad = CGRect(x: window.minX, y: window.maxY + (detail ? 44 : 50), width: window.width,
                     height: face.maxY - (detail ? 70 : 76) - window.maxY - (detail ? 44 : 50))
    let gap: CGFloat = detail ? 26 : 40
    let width = (pad.width - gap * CGFloat(columns - 1)) / CGFloat(columns)
    let height = (pad.height - gap * CGFloat(rows - 1)) / CGFloat(rows)
    let symbols: [Symbol] = [.divide, .times, .minus, .plus]
    for row in 0..<rows {
        for column in 0..<columns {
            let rect = CGRect(x: pad.minX + CGFloat(column) * (width + gap), y: pad.minY + CGFloat(row) * (height + gap),
                              width: width, height: height)
            let last = column == columns - 1
            if last && row == rows - 1 {
                key(context, rect, orangeKey, .equals, detail: detail)
            } else if last {
                key(context, rect, blueKey, symbols[row + 1], detail: detail)
            } else {
                key(context, rect, creamKey, .none, detail: detail)
            }
        }
    }
}

func drawIcon(_ context: CGContext, detail: Bool) {
    // Dark copies stepped along the depth direction fake the extruded edge of the body.
    context.beginTransparencyLayer(auxiliaryInfo: nil)
    for step in stride(from: edgeDepth, through: 1, by: -1) {
        context.saveGState()
        context.translateBy(x: CGFloat(step) * 0.55, y: CGFloat(step))
        context.concatenate(lean)
        context.addPath(body())
        context.setFillColor(rgb(0x0B2F8A)); context.fillPath()
        context.restoreGState()
    }
    context.endTransparencyLayer()

    context.saveGState()
    context.concatenate(lean)
    drawCalculator(context, detail: detail)
    context.restoreGState()
}

// MARK: Output

func bitmap(_ pixels: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: pixels, height: pixels)
    return rep
}

/// Renders the artwork with `fit` mapping face space onto a y-down square of `pixels`.
func render(_ pixels: Int, fit: CGAffineTransform) -> NSBitmapImageRep {
    let rep = bitmap(pixels)
    let context = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
    context.interpolationQuality = .high
    context.translateBy(x: 0, y: CGFloat(pixels))
    context.scaleBy(x: 1, y: -1)
    context.concatenate(fit)
    shadowScale = fit.a
    drawIcon(context, detail: pixels >= 64)
    return rep
}

// Measure the opaque bounds once, then scale the artwork edge to edge at every size.
let probeScale: CGFloat = 0.5, probeOffset: CGFloat = 500
let probe = render(1024, fit: CGAffineTransform(a: probeScale, b: 0, c: 0, d: probeScale, tx: probeOffset * probeScale, ty: probeOffset * probeScale))
var minX = 1024, minY = 1024, maxX = -1, maxY = -1
let data = probe.bitmapData!, rowBytes = probe.bytesPerRow
for y in 0..<1024 {
    for x in 0..<1024 where data[y * rowBytes + x * 4 + 3] > 24 {
        minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
    }
}
guard maxX >= 0 else { fatalError("Icon artwork rendered empty") }
let bounds = CGRect(x: CGFloat(minX) / probeScale - probeOffset, y: CGFloat(minY) / probeScale - probeOffset,
                    width: CGFloat(maxX - minX + 1) / probeScale, height: CGFloat(maxY - minY + 1) / probeScale)

func png(_ pixels: Int) -> Data {
    let side = CGFloat(pixels), margin = side * 0.012
    let factor = (side - margin * 2) / max(bounds.width, bounds.height)
    let fit = CGAffineTransform(a: factor, b: 0, c: 0, d: factor,
                                tx: (side - bounds.width * factor) / 2 - bounds.minX * factor,
                                ty: (side - bounds.height * factor) / 2 - bounds.minY * factor)
    return render(pixels, fit: fit).representation(using: .png, properties: [:])!
}

let output = URL(fileURLWithPath: arguments[1])
let iconset = FileManager.default.temporaryDirectory
    .appendingPathComponent("MyCalc-\(ProcessInfo.processInfo.globallyUniqueString).iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: iconset) }
for points in [16, 32, 128, 256, 512] {
    try png(points).write(to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try png(points * 2).write(to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { exit(1) }
if arguments.count >= 3 {
    try png(1024).write(to: URL(fileURLWithPath: arguments[2]))
}
