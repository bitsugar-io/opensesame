import CoreGraphics
import Testing
@testable import OpenSesameCore

@Test func desktopChoicesDependOnExposureNotForegroundApp() {
    let screen = CGRect(x: 1000, y: 200, width: 1000, height: 800)
    let icon = CGRect(x: 1900, y: 240, width: 64, height: 64)
    #expect(DesktopVisibility.isExposed(icon, screens: [screen], occluders: [CGRect(x: 1050, y: 200, width: 800, height: 800)]))
    let partial = DesktopVisibility.exposed(icon, screens: [screen], occluders: [CGRect(x: 1800, y: 200, width: 120, height: 800)])
    #expect(partial == [CGRect(x: 1920, y: 240, width: 44, height: 64)])
    #expect(!DesktopVisibility.isExposed(icon, screens: [screen], occluders: [screen]))
    #expect(!DesktopVisibility.isExposed(icon.offsetBy(dx: 100, dy: 0), screens: [screen], occluders: []))
}

@Test func desktopTagsRemainInsideExposedCornersWithoutCoveringAnotherWindow() {
    let icon = CGRect(x: 100, y: 100, width: 64, height: 64)
    let screen = CGRect(x: 0, y: 0, width: 500, height: 500)
    let visible = [CGRect(x: 120, y: 100, width: 44, height: 64)]
    let badge = CGSize(width: 30, height: 24)
    #expect(BadgeLayout.insideObject(control: icon, visible: visible, badge: badge, bounds: screen, occupied: []) == CGRect(x: 130, y: 136, width: 30, height: 24))
    #expect(BadgeLayout.insideObject(control: icon, visible: visible, badge: CGSize(width: 80, height: 24), bounds: screen, occupied: []) == nil)
    #expect(BadgeLayout.insideObject(control: icon, visible: [], badge: badge, bounds: screen, occupied: []) == nil)
}

@Test func desktopUsesItsOwnConsistentColorFamilyInEveryTheme() {
    for theme in AppTheme.allCases {
        for dark in [false, true] {
            let palette = ThemePalette(theme: theme, dark: dark)
            let desktop = HintStyle.colors(kind: .desktop, index: 0, palette: palette)
            #expect(desktop.accent == palette.window)
            for kind in [TargetKind.control, .menu, .tab] {
                #expect(desktop.accent != HintStyle.colors(kind: kind, index: 0, palette: palette).accent)
            }
        }
    }
}
