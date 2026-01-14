#!/usr/bin/env swift

import AppKit
import Foundation

// Makes corners transparent with macOS Big Sur+ icon corner radius

guard CommandLine.arguments.count >= 2 else {
    print("Usage: fix_corners <input.png> [output.png]")
    print("If output not specified, overwrites input file")
    exit(1)
}

let inputPath = CommandLine.arguments[1]
let outputPath = CommandLine.arguments.count >= 3 ? CommandLine.arguments[2] : inputPath

guard let inputImage = NSImage(contentsOfFile: inputPath) else {
    print("Error: Could not load image from \(inputPath)")
    exit(1)
}

let size = inputImage.size
let pixelSize = Int(size.width)

print("Processing \(pixelSize)x\(pixelSize) image...")

// Create bitmap context
guard let context = CGContext(
    data: nil,
    width: pixelSize,
    height: pixelSize,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
) else {
    print("Error: Could not create graphics context")
    exit(1)
}

let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)

// macOS Big Sur+ icon corner radius (~22.37% of size)
let cornerRadius = size.width * 0.2237

// Create rounded rect path
let roundedPath = CGPath(roundedRect: rect,
                         cornerWidth: cornerRadius,
                         cornerHeight: cornerRadius,
                         transform: nil)

// Clip to rounded rect (corners become transparent)
context.addPath(roundedPath)
context.clip()

// Draw the original image
if let cgImage = inputImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
    context.draw(cgImage, in: rect)
}

// Create output image
guard let outputCGImage = context.makeImage() else {
    print("Error: Could not create output image")
    exit(1)
}

let bitmapRep = NSBitmapImageRep(cgImage: outputCGImage)
bitmapRep.size = size

guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
    print("Error: Could not create PNG data")
    exit(1)
}

do {
    try pngData.write(to: URL(fileURLWithPath: outputPath))
    print("Saved to \(outputPath)")
} catch {
    print("Error writing file: \(error)")
    exit(1)
}
