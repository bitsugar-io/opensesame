import CoreGraphics

public enum DesktopVisibility {
    public static func exposed(_ frame: CGRect, screens: [CGRect], occluders: [CGRect]) -> [CGRect] {
        VisibleRegion.exposed(frame: frame, screens: screens, occluders: occluders)
    }
    public static func isExposed(_ frame: CGRect, screens: [CGRect], occluders: [CGRect]) -> Bool {
        !exposed(frame, screens: screens, occluders: occluders).isEmpty
    }
}
