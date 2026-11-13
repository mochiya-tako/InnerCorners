import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum IconError: Error, CustomStringConvertible {
    case usage
    case load(String)
    case context
    case encode(String)
    case emptyAlpha

    var description: String {
        switch self {
        case .usage: "usage: generate_icons APP_PNG MENU_PNG OUTPUT_DIR"
        case .load(let path): "could not load image: \(path)"
        case .context: "could not create bitmap context"
        case .encode(let path): "could not encode PNG: \(path)"
        case .emptyAlpha: "menu icon has no visible alpha pixels"
        }
    }
}

func loadImage(_ path: String) throws -> CGImage {
    let url = URL(fileURLWithPath: path) as CFURL
    guard
        let source = CGImageSourceCreateWithURL(url, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { throw IconError.load(path) }
    return image
}

func makeContext(width: Int, height: Int) throws -> CGContext {
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { throw IconError.context }
    context.interpolationQuality = .high
    return context
}

func writePNG(_ image: CGImage, to path: String) throws {
    let url = URL(fileURLWithPath: path) as CFURL
    guard let destination = CGImageDestinationCreateWithURL(
        url,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else { throw IconError.encode(path) }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw IconError.encode(path) }
}

func pngData(_ image: CGImage) throws -> Data {
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(
        data,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else { throw IconError.encode("memory") }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw IconError.encode("memory") }
    return data as Data
}

func appendBigEndian(_ value: UInt32, to data: inout Data) {
    var encoded = value.bigEndian
    withUnsafeBytes(of: &encoded) { data.append(contentsOf: $0) }
}

func writeICNS(_ entries: [(String, CGImage)], to path: String) throws {
    let encoded = try entries.map { (type, image) -> (String, Data) in
        (type, try pngData(image))
    }
    let totalSize = 8 + encoded.reduce(0) { $0 + 8 + $1.1.count }
    var result = Data("icns".utf8)
    appendBigEndian(UInt32(totalSize), to: &result)
    for (type, payload) in encoded {
        result.append(contentsOf: type.utf8)
        appendBigEndian(UInt32(payload.count + 8), to: &result)
        result.append(payload)
    }
    do {
        try result.write(to: URL(fileURLWithPath: path), options: .atomic)
    } catch {
        throw IconError.encode(path)
    }
}

func renderSquare(_ image: CGImage, size: Int, insetFraction: CGFloat = 0) throws -> CGImage {
    let context = try makeContext(width: size, height: size)
    context.clear(CGRect(x: 0, y: 0, width: size, height: size))
    let inset = CGFloat(size) * insetFraction
    context.draw(image, in: CGRect(
        x: inset,
        y: inset,
        width: CGFloat(size) - inset * 2,
        height: CGFloat(size) - inset * 2
    ))
    guard let result = context.makeImage() else { throw IconError.context }
    return result
}

func alphaBounds(of image: CGImage) throws -> CGRect {
    let width = image.width
    let height = image.height
    let context = try makeContext(width: width, height: height)
    context.clear(CGRect(x: 0, y: 0, width: width, height: height))
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    guard let data = context.data else { throw IconError.context }
    let bytes = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
    var minX = width
    var minY = height
    var maxX = -1
    var maxY = -1
    for y in 0..<height {
        for x in 0..<width where bytes[(y * width + x) * 4 + 3] > 4 {
            minX = min(minX, x)
            minY = min(minY, y)
            maxX = max(maxX, x)
            maxY = max(maxY, y)
        }
    }
    guard maxX >= minX, maxY >= minY else { throw IconError.emptyAlpha }
    return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
}

func renderMenuIcon(_ image: CGImage, alphaBounds: CGRect, size: Int) throws -> CGImage {
    let padding = max(alphaBounds.width, alphaBounds.height) * 0.06
    let crop = alphaBounds.insetBy(dx: -padding, dy: -padding).intersection(
        CGRect(x: 0, y: 0, width: image.width, height: image.height)
    ).integral
    guard let cropped = image.cropping(to: crop) else { throw IconError.context }
    let context = try makeContext(width: size, height: size)
    context.clear(CGRect(x: 0, y: 0, width: size, height: size))
    let scale = min(CGFloat(size) / CGFloat(cropped.width), CGFloat(size) / CGFloat(cropped.height))
    let drawWidth = CGFloat(cropped.width) * scale
    let drawHeight = CGFloat(cropped.height) * scale
    context.draw(cropped, in: CGRect(
        x: (CGFloat(size) - drawWidth) / 2,
        y: (CGFloat(size) - drawHeight) / 2,
        width: drawWidth,
        height: drawHeight
    ))
    guard let result = context.makeImage() else { throw IconError.context }
    return result
}

do {
    guard CommandLine.arguments.count == 4 else { throw IconError.usage }
    let appSource = try loadImage(CommandLine.arguments[1])
    let menuSource = try loadImage(CommandLine.arguments[2])
    let output = CommandLine.arguments[3]
    try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)
    let appSizes: [(String, Int)] = [
        ("icp4", 16),
        ("icp5", 32),
        ("icp6", 64),
        ("ic07", 128),
        ("ic08", 256),
        ("ic09", 512),
        ("ic10", 1024)
    ]
    try writeICNS(
        try appSizes.map { type, size in (type, try renderSquare(appSource, size: size)) },
        to: output + "/AppIcon.icns"
    )

    let bounds = try alphaBounds(of: menuSource)
    try writePNG(
        try renderMenuIcon(menuSource, alphaBounds: bounds, size: 18),
        to: output + "/MenuBarIcon.png"
    )
    try writePNG(
        try renderMenuIcon(menuSource, alphaBounds: bounds, size: 36),
        to: output + "/MenuBarIcon@2x.png"
    )
    print("menu alpha bounds: \(Int(bounds.minX)),\(Int(bounds.minY)) \(Int(bounds.width))x\(Int(bounds.height))")
} catch {
    FileHandle.standardError.write(Data("\(error)\n".utf8))
    exit(1)
}
