import AppKit
import OpenSesameBrand

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)
let assets = root.appendingPathComponent("asset")
let iconset = root.appendingPathComponent(".build/branding/OpenSesame.iconset")
try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try BrandArtwork.png(BrandArtwork.appIcon(), pixels: size * scale).write(to: iconset.appendingPathComponent(name))
    }
}
try BrandArtwork.png(BrandArtwork.appIcon(), pixels: 512).write(to: assets.appendingPathComponent("icon.png"))
for dark in [true, false] {
    try BrandArtwork.svg(dark: dark, banner: true).write(to: assets.appendingPathComponent("logo-\(dark ? "dark" : "light").svg"), atomically: true, encoding: .utf8)
    try BrandArtwork.svg(dark: dark, banner: false).write(to: assets.appendingPathComponent("mark-\(dark ? "dark" : "light").svg"), atomically: true, encoding: .utf8)
}
print("Generated OpenSesame artwork in \(assets.path)")
