import AppKit
import UniformTypeIdentifiers
import ImageIO

/// Shared local app identity for overflow panels and saved places. No network
/// requests or screen captures are needed to decorate a navigation choice.
enum AppIdentity {
    private static var icons: [String: NSImage] = [:]
    static func icon(bundleID: String) -> NSImage {
        if let cached = icons[bundleID] { return cached }
        if let icon = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first?.icon {
            icons[bundleID] = icon
            return icon
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            icons[bundleID] = icon
            return icon
        }
        return NSWorkspace.shared.icon(for: .applicationBundle)
    }
    static func name(bundleID: String) -> String {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first?.localizedName
            ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)?.deletingPathExtension().lastPathComponent
            ?? bundleID
    }
}

enum TargetPresentation {
    static func sourceKey(_ target: Target) -> String {
        target.kind == .desktop ? "desktop" : "\(target.metadata.bundleID):\(target.metadata.owner)"
    }
    static func caption(_ target: Target) -> String {
        let metadata = target.metadata
        // Tab titles identify the destination; descriptions often prepend an
        // app name or repeat structural information about the tab strip.
        let raw = target.kind == .tab || target.kind == .window || target.kind == .desktop
            ? (metadata.title.isEmpty ? metadata.description : metadata.title)
            : (metadata.description.isEmpty ? metadata.title : metadata.description)
        return raw.isEmpty ? metadata.role.replacingOccurrences(of: "AX", with: "") : raw
    }
    static func sourceName(_ target: Target, fallback: String) -> String {
        if target.kind == .desktop { return "Desktop" }
        let name = AppIdentity.name(bundleID: target.metadata.bundleID)
        return name.isEmpty || name == "preview" ? fallback : name
    }
    static func icon(_ target: Target, foreground: NSColor) -> NSImage {
        if let data = target.metadata.iconData, data.count <= 262144,
           let source = CGImageSourceCreateWithData(data as CFData, nil),
           let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 32] as CFDictionary) {
            return NSImage(cgImage: image, size: NSSize(width: 16, height: 16))
        }
        let symbol = target.metadata.isDisclosure || target.metadata.role == "AXTabGroup" ? "square.stack.3d.up"
            : (target.kind == .desktop ? "doc" : nil)
        if let symbol, let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) {
            return image.withSymbolConfiguration(.init(paletteColors: [foreground])) ?? image
        }
        return AppIdentity.icon(bundleID: target.metadata.bundleID)
    }
}
