import AppKit

let S: CGFloat = 1024
let img = NSImage(size: NSSize(width: S, height: S))
img.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

// background
let bg = NSColor(srgbRed: 0.043, green: 0.043, blue: 0.051, alpha: 1)
ctx.setFillColor(bg.cgColor)
ctx.fill(CGRect(x: 0, y: 0, width: S, height: S))

// dot grid
ctx.setFillColor(NSColor(srgbRed: 1, green: 0.353, blue: 0.122, alpha: 0.10).cgColor)
var y: CGFloat = 40
while y < S {
    var x: CGFloat = 40
    while x < S {
        ctx.fillEllipse(in: CGRect(x: x, y: y, width: 5, height: 5))
        x += 56
    }
    y += 56
}

// soft orange glow
if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                         colors: [NSColor(srgbRed: 1, green: 0.353, blue: 0.122, alpha: 0.30).cgColor,
                                  NSColor(srgbRed: 1, green: 0.353, blue: 0.122, alpha: 0).cgColor] as CFArray,
                         locations: [0, 1]) {
    ctx.drawRadialGradient(grad, startCenter: CGPoint(x: S * 0.5, y: S * 0.45), startRadius: 10,
                           endCenter: CGPoint(x: S * 0.5, y: S * 0.45), endRadius: S * 0.55, options: [])
}

let orange = NSColor(srgbRed: 1, green: 0.353, blue: 0.122, alpha: 1)
let center = CGPoint(x: S * 0.5, y: S * 0.55)
let radius: CGFloat = S * 0.26
let lineW: CGFloat = S * 0.105

// horseshoe arc
ctx.setStrokeColor(orange.cgColor)
ctx.setLineWidth(lineW)
ctx.setLineCap(.round)
ctx.addArc(center: center, radius: radius, startAngle: .pi * 0.12, endAngle: .pi * 0.88, clockwise: false)
ctx.strokePath()

// legs
ctx.setLineWidth(lineW)
ctx.move(to: CGPoint(x: center.x - radius, y: center.y))
ctx.addLine(to: CGPoint(x: center.x - radius, y: S * 0.20))
ctx.move(to: CGPoint(x: center.x + radius, y: center.y))
ctx.addLine(to: CGPoint(x: center.x + radius, y: S * 0.20))
ctx.strokePath()

// white candle
ctx.setStrokeColor(NSColor.white.cgColor)
ctx.setLineWidth(S * 0.028)
ctx.move(to: CGPoint(x: center.x, y: S * 0.30))
ctx.addLine(to: CGPoint(x: center.x, y: S * 0.78))
ctx.strokePath()

let body = CGRect(x: center.x - S * 0.062, y: S * 0.45, width: S * 0.124, height: S * 0.20)
ctx.setFillColor(NSColor.white.cgColor)
ctx.fill(body)

// orange tick under the candle
ctx.setFillColor(orange.cgColor)
ctx.fill(CGRect(x: center.x - S * 0.062, y: S * 0.30, width: S * 0.124, height: S * 0.028))

img.unlockFocus()

let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
print("icon written")
