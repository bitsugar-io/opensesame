import AppKit
import OpenSesameCore

private struct DrawnHint {
    let label: String
    let badge: CGRect
    let accent: NSColor
    let text: NSAttributedString
    let connector: NSBezierPath
    let caption: NSAttributedString?
}

final class HintCanvas: NSView {
    var palette = ThemePalette(theme: .glitch, dark: true)
    var targets: [Target] = []
    var prefix = ""
    var fontSize: CGFloat = 16
    var screenFrame = CGRect.zero
    var desktopTop: CGFloat = 0
    var scopeFrame: CGRect?
    var textFrames: [CGRect] = []
    private(set) var drawnLabels = Set<String>()
    private(set) var usesLedger = false
    private(set) var localLabels = Set<String>()
    private(set) var overflowLabels = Set<String>()
    private var captionFont: NSFont { .systemFont(ofSize: max(12, fontSize - 2), weight: .medium) }
    private var captionHeight: CGFloat { ceil(captionFont.ascender - captionFont.descender + captionFont.leading) + 4 }
    private func shortCaption(_ target: Target) -> String {
        let raw = target.metadata.description.isEmpty ? target.metadata.title : target.metadata.description
        return raw.replacingOccurrences(of: " minutes", with: "m").replacingOccurrences(of: " minute", with: "m")
            .replacingOccurrences(of: " hours", with: "h").replacingOccurrences(of: " hour", with: "h")
            .replacingOccurrences(of: "Indefinitely", with: "∞").replacingOccurrences(of: "Custom duration", with: "Custom")
    }
    private func drawPanel(_ rect: CGRect) {
        NSColor(rgb: palette.background).setFill()
        let plate = NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10)
        plate.fill()
        NSColor(rgb: palette.control).withAlphaComponent(0.65).setStroke()
        plate.lineWidth = 1; plate.stroke()
    }
    var scopedPopup = false
    var ledgerPage = 0
    override func draw(_ dirtyRect: NSRect) {
        drawnLabels.removeAll()
        usesLedger = false
        localLabels.removeAll(); overflowLabels.removeAll()
        drawSectionOutlines()
        if scopedPopup && targets.allSatisfy({ $0.metadata.role == "AXMenuItem" }) { usesLedger = true; drawLedger(); return }
        var overflowTargets: [Target] = []
        var overflowPage: LedgerPage?
        var occupied: [CGRect] = []
        var drawings: [DrawnHint] = []
        let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
        let badgeTextSize = targets.map { ($0.label.uppercased() as NSString).size(withAttributes: [.font: font]) }
        let badgeSize = CGSize(width: ceil(badgeTextSize.map(\.width).max() ?? fontSize) + 16, height: ceil(badgeTextSize.map(\.height).max() ?? fontSize) + 6)
        let controlRects = targets.filter { $0.kind != .window && $0.metadata.role != "OpenSesameSection" }.map { target in
            CGRect(x: target.frame.minX - screenFrame.minX,
                   y: desktopTop - target.frame.maxY - screenFrame.minY,
                   width: target.frame.width, height: target.frame.height)
        }
        let reportedSurface = scopeFrame.map { CGRect(x: $0.minX - screenFrame.minX, y: desktopTop - $0.maxY - screenFrame.minY, width: $0.width, height: $0.height) }
        let rowControls = targets.enumerated().compactMap { index, target -> CompactRowLayout.Control? in
            guard target.metadata.role != "OpenSesameSection", target.kind == .control, ["AXButton", "AXRadioButton", "AXCheckBox"].contains(target.metadata.role) else { return nil }
            let frame = CGRect(x: target.frame.minX - screenFrame.minX, y: desktopTop - target.frame.maxY - screenFrame.minY, width: target.frame.width, height: target.frame.height)
            guard bounds.intersects(frame) else { return nil }
            return CompactRowLayout.Control(index: index, owner: target.metadata.owner, frame: frame)
        }
        let textObstacles = textFrames.map { CGRect(x: $0.minX - screenFrame.minX, y: desktopTop - $0.maxY - screenFrame.minY, width: $0.width, height: $0.height) }
        let localSurface = reportedSurface.map { scopedPopup ? WidgetLayout.contentSurface(reported: $0, controls: controlRects, text: textObstacles) : $0 }
        // Reserve readable captions before placement, rather than painting
        // larger text into the old ten-point caption's collision footprint.
        let rowCaptionWidth = rowControls.map { index in
            (shortCaption(targets[index.index]) as NSString).size(withAttributes: [.font: captionFont]).width + 12
        }.max() ?? 0
        let rowBadge = CGSize(width: max(badgeSize.width, min(rowCaptionWidth, max(64, fontSize * 4))), height: badgeSize.height)
        let compact = CompactRowLayout.arrange(controls: rowControls, badge: rowBadge, bounds: bounds,
                                               surface: localSurface, obstacles: controlRects + textObstacles, captionHeight: captionHeight)
        let ordered = targets.enumerated().sorted {
            if ($0.element.kind == .window) != ($1.element.kind == .window) { return $0.element.kind == .window }
            if (compact[$0.offset] != nil) != (compact[$1.offset] != nil) { return compact[$0.offset] != nil }
            return $0.offset < $1.offset
        }
        for (index, target) in ordered {
            let isSection = target.metadata.role == "OpenSesameSection"
            let global = CGRect(x: target.frame.minX, y: desktopTop - target.frame.maxY, width: target.frame.width, height: target.frame.height)
            let rect = global.offsetBy(dx: -screenFrame.minX, dy: -screenFrame.minY)
            guard rect.intersects(bounds) else { continue }
            let accent: NSColor
            switch target.kind {
            case .window: accent = NSColor(rgb: palette.window)
            case .tab: accent = NSColor(rgb: palette.tab)
            case .close: accent = NSColor(calibratedRed: 1, green: 0.73, blue: 0.33, alpha: 1)
            default:
                accent = index.isMultiple(of: 2)
                    ? NSColor(rgb: palette.control)
                    : NSColor(rgb: palette.alternate)
            }
            let inlineTabFrame = target.kind == .tab && target.metadata.bundleID == "com.mitchellh.ghostty"
                ? BadgeLayout.inlineTab(control: rect, badge: badgeSize) : nil
            let inlineTab = inlineTabFrame != nil
            let label = target.label.uppercased()
            // Keep the code compact: only close actions need an extra glyph.
            let text = (isSection ? label + " · " + target.metadata.title : (target.kind == .close ? "× " + label : label)) as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: inlineTab ? NSFont.systemFont(ofSize: min(fontSize, max(10, rect.height - 6)), weight: .bold) : font,
                .foregroundColor: accent
            ]
            let styled = NSMutableAttributedString(string: text as String, attributes: attributes)
            let codeOffset = target.kind == .close ? 2 : 0
            if !prefix.isEmpty {
                let typedAccent: NSColor
                switch target.kind {
                case .tab, .window:
                    typedAccent = NSColor(rgb: palette.control)
                default:
                    typedAccent = index.isMultiple(of: 2)
                        ? NSColor(rgb: palette.typedControl)
                        : NSColor(rgb: palette.typedAlternate)
                }
                styled.addAttribute(.foregroundColor, value: typedAccent,
                                    range: NSRange(location: codeOffset, length: prefix.count))
            }
            let isMenuBar = target.metadata.role == "AXMenuBarItem" ||
                (bounds.maxY - rect.maxY < 28 && rect.height <= 28)
            // Every control on an opened surface shares its outside rails.
            // Connectors still point to the individual controls.
            let placementRect = rect
            let reservedRows = compact.filter { $0.key != index }.map { $0.value.reservation }
            let nearby = target.kind == .control && compact[index] == nil
                ? WidgetLayout.nearby(control: rect, badge: badgeSize, bounds: bounds, occupied: occupied + reservedRows,
                                      controls: controlRects, text: textObstacles) : nil
            let exteriorBadge = CGSize(width: max(badgeSize.width, min(200,
                ceil((shortCaption(target) as NSString).size(withAttributes: [.font: captionFont]).width) + 12)), height: badgeSize.height)
            let exterior = target.kind == .control && compact[index] == nil && nearby == nil
                ? WidgetLayout.exterior(control: rect, surface: localSurface ?? rect, badge: exteriorBadge, bounds: bounds,
                                        occupied: occupied + reservedRows, obstacles: controlRects + textObstacles, captionHeight: captionHeight) : nil
            let candidates: [CGRect]
            if isSection {
                let size = CGSize(width: ceil(styled.size().width) + 16, height: badgeSize.height)
                candidates = SectionLabelLayout.candidates(section: rect, badge: size, bounds: bounds)
            } else if let placement = compact[index] {
                candidates = [placement.frame]
            } else if let nearby {
                candidates = [nearby]
            } else if inlineTabFrame != nil {
                candidates = BadgeLayout.inlineTabCandidates(control: rect, badge: badgeSize)
            } else if target.kind == .window {
                // The window selector has a distinct location as well as color.
                candidates = BadgeLayout.windowTitle(control: rect, badge: badgeSize)
            } else if target.kind == .control {
                candidates = exterior.map { [$0] } ?? []
            } else {
                candidates = BadgeLayout.candidates(control: placementRect, badge: badgeSize,
                                                   menuBar: isMenuBar, index: index, bounds: bounds)
            }
            let sectionCandidates = isSection ? candidates.filter { candidate in
                !(controlRects + textObstacles).contains { $0.insetBy(dx: -3, dy: -3).intersects(candidate) }
            } : candidates
            guard let badge = BadgeLayout.place(candidates: sectionCandidates, bounds: bounds,
                                                occupied: occupied + reservedRows, controls: controlRects, spacing: target.kind == .control ? 3 : 5) else {
                overflowTargets.append(target)
                continue
            }
            occupied.append(compact[index].flatMap { $0.frame == badge ? $0.reservation : nil } ?? (exterior == badge ? badge.union(badge.offsetBy(dx: 0, dy: -captionHeight)) : badge))
            // Reserve every position even when filtering, so surviving badges
            // never change lanes as the user types.
            guard target.label.hasPrefix(prefix) else { continue }
            // One continuous path joins the target and badge, including any
            // local stagger. No detached ticks or diagonal connector segments.
            let anchorRect = rect
            let anchorX = min(max(badge.midX, anchorRect.minX + 1), anchorRect.maxX - 1)
            let anchor = CGPoint(x: anchorX, y: min(max(badge.midY, anchorRect.minY + 1), anchorRect.maxY - 1))
            let endpoint = CGPoint(x: min(max(anchor.x, badge.minX), badge.maxX),
                                   y: min(max(anchor.y, badge.minY), badge.maxY))
            let connector = NSBezierPath()
            if let placement = compact[index], badge == placement.frame {
                // A single horizontal strip maps left to right to this control row.
            } else if let nearby, badge == nearby {
                if !rect.contains(badge) {
                    if badge.maxY <= rect.minY {
                        connector.move(to: CGPoint(x: rect.midX, y: rect.minY)); connector.line(to: CGPoint(x: rect.midX, y: badge.maxY))
                    } else if badge.minY >= rect.maxY {
                        connector.move(to: CGPoint(x: rect.midX, y: rect.maxY)); connector.line(to: CGPoint(x: rect.midX, y: badge.minY))
                    } else if badge.minX >= rect.maxX {
                        connector.move(to: CGPoint(x: rect.maxX, y: rect.midY)); connector.line(to: CGPoint(x: badge.minX, y: rect.midY))
                    } else {
                        connector.move(to: CGPoint(x: rect.minX, y: rect.midY)); connector.line(to: CGPoint(x: badge.maxX, y: rect.midY))
                    }
                }
            } else if exterior != badge && target.kind != .window && !inlineTab && !isSection {
                connector.move(to: anchor)
                if abs(anchor.x - endpoint.x) > 0.5 && abs(anchor.y - endpoint.y) > 0.5 {
                    connector.line(to: CGPoint(x: anchor.x, y: endpoint.y))
                }
                connector.line(to: endpoint)
            }
            var caption: NSAttributedString?
            if (compact[index].map { $0.outsideSurface && badge == $0.frame } ?? false) || exterior == badge {
                caption = NSAttributedString(string: shortCaption(target), attributes: [.font: captionFont, .foregroundColor: NSColor(rgb: palette.text)])
            }
            drawnLabels.insert(target.label)
            drawings.append(DrawnHint(label: target.label, badge: badge, accent: accent, text: styled, connector: connector, caption: caption))
        }
        if !overflowTargets.isEmpty {
            // Keep successful local hints. Move only unplaced hints (and any
            // badge the overflow panel would cover) into the paged panel.
            var missing = Set(overflowTargets.map(\.label))
            for _ in 0..<targets.count {
                overflowTargets = targets.filter { missing.contains($0.label) }
                let reservations = drawings.filter { !missing.contains($0.label) }.map { drawing in
                    drawing.caption == nil ? drawing.badge : drawing.badge.union(drawing.badge.offsetBy(dx: 0, dy: -captionHeight))
                }
                let page = ledgerGeometry(for: overflowTargets, localized: true, avoid: reservations)
                overflowPage = page
                let panel = page.panel
                let covered = drawings.filter { drawing in
                    let reservation = drawing.caption == nil ? drawing.badge
                        : drawing.badge.union(drawing.badge.offsetBy(dx: 0, dy: -captionHeight))
                    return panel.insetBy(dx: -5, dy: -5).intersects(reservation)
                }.map(\.label)
                let before = missing.count
                missing.formUnion(covered)
                if missing.count == before { break }
            }
            overflowTargets = targets.filter { missing.contains($0.label) }
            overflowLabels = missing
            drawings.removeAll { missing.contains($0.label) }
            drawnLabels.subtract(missing)
            usesLedger = true
        }
        localLabels = Set(drawings.map(\.label))
        // Connectors form a background layer. A later target's line must never
        // draw across the code on an earlier badge.
        for drawing in drawings {
            drawing.accent.withAlphaComponent(0.8).setStroke()
            drawing.connector.lineWidth = 1.5
            drawing.connector.stroke()
        }
        // Exterior annotations form one opaque panel per horizontal row,
        // sharing the same surface styling as the vertical menu ledger.
        var strips: [[DrawnHint]] = []
        for drawing in drawings.filter({ $0.caption != nil }).sorted(by: { $0.badge.minX < $1.badge.minX }) {
            if let row = strips.firstIndex(where: {
                abs($0[0].badge.minY - drawing.badge.minY) < 1 &&
                $0.last!.badge.maxX + max(24, drawing.badge.width) >= drawing.badge.minX
            }) { strips[row].append(drawing) }
            else { strips.append([drawing]) }
        }
        for strip in strips {
            let panel = strip.reduce(CGRect.null) { result, drawing in
                result.union(drawing.badge.union(drawing.badge.offsetBy(dx: 0, dy: -captionHeight)))
            }.insetBy(dx: -4, dy: -3)
            drawPanel(panel)
        }
        for drawing in drawings {
            if drawing.caption == nil {
                NSColor(rgb: palette.background).setFill()
                let plate = NSBezierPath(roundedRect: drawing.badge, xRadius: 4, yRadius: 4)
                plate.fill()
                drawing.accent.withAlphaComponent(0.55).setStroke()
                plate.lineWidth = 1; plate.stroke()
            }
            if let caption = drawing.caption {
                let captionRect = CGRect(x: drawing.badge.minX - 2, y: drawing.badge.minY - captionHeight,
                                         width: drawing.badge.width + 4, height: captionHeight)
                let style = NSMutableParagraphStyle(); style.alignment = .center; style.lineBreakMode = .byTruncatingTail
                let styledCaption = NSMutableAttributedString(attributedString: caption)
                styledCaption.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: styledCaption.length))
                styledCaption.draw(in: captionRect)
            }
            drawing.text.draw(at: CGPoint(x: drawing.caption == nil ? drawing.badge.minX + 8 : drawing.badge.midX - drawing.text.size().width / 2,
                                         y: drawing.badge.midY - drawing.text.size().height / 2))
        }
        if !overflowTargets.isEmpty { drawLedger(items: overflowTargets, localized: true, pageOverride: overflowPage) }
    }
    private func drawSectionOutlines() {
        for target in targets where target.metadata.role == "OpenSesameSection" && target.label.hasPrefix(prefix) {
            let rect = CGRect(x: target.frame.minX - screenFrame.minX,
                y: desktopTop - target.frame.maxY - screenFrame.minY, width: target.frame.width, height: target.frame.height)
            guard rect.intersects(bounds) else { continue }
            let color = NSColor(rgb: palette.control)
            // Outlines preserve underlying text even when section regions
            // overlap; repeated translucent fills would accumulate opacity.
            let outline = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)
            color.withAlphaComponent(0.8).setStroke(); outline.lineWidth = 1.5; outline.stroke()
        }
    }
    private func ledgerGeometry(for visible: [Target], localized: Bool, avoid: [CGRect] = []) -> LedgerPage {
        let local: (CGRect) -> CGRect = { frame in
            CGRect(x: frame.minX - self.screenFrame.minX, y: self.desktopTop - frame.maxY - self.screenFrame.minY, width: frame.width, height: frame.height)
        }
        let controls = visible.map { local($0.frame) }
        let reported = (localized ? nil : scopeFrame.map(local)) ?? controls.reduce(CGRect.null) { $0.union($1) }
        let surface = WidgetLayout.contentSurface(reported: reported, controls: controls, text: textFrames.map(local))
        let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
        let codeWidth = ceil((String(repeating: "M", count: visible.map(\.label.count).max() ?? 2) as NSString).size(withAttributes: [.font: font]).width) + 12
        return LedgerPage(items: visible.filter { $0.label.hasPrefix(prefix) }.count, requestedPage: ledgerPage,
                          bounds: bounds, surface: surface, fontSize: fontSize, codeWidth: codeWidth, avoid: avoid)
    }
    private func drawLedger(items: [Target]? = nil, localized: Bool = false, pageOverride: LedgerPage? = nil) {
        let visible = (items ?? targets).filter { target in
            CGRect(x: target.frame.minX - screenFrame.minX, y: desktopTop - target.frame.maxY - screenFrame.minY,
                   width: target.frame.width, height: target.frame.height).intersects(bounds)
        }
        guard !visible.isEmpty else { return }
        let matching = visible.filter { $0.label.hasPrefix(prefix) }
        let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
        let codeWidth = ceil((String(repeating: "M", count: visible.map(\.label.count).max() ?? 2) as NSString).size(withAttributes: [.font: font]).width) + 12
        let page = pageOverride ?? ledgerGeometry(for: visible, localized: localized)
        let shown = Array(matching[page.range])
        let panel = page.panel, rowHeight = page.rowHeight, columnWidth = page.columnWidth
        let perColumn = page.rowsPerColumn
        drawPanel(panel)
        let heading = localized ? "More controls" : (targets.contains { $0.metadata.role == "OpenSesameSection" } ? "Choose a section or window" : "Choose an action")
        (heading as NSString).draw(at: CGPoint(x: panel.minX + 12, y: panel.maxY - 25), withAttributes: [.font: NSFont.systemFont(ofSize: 11, weight: .semibold), .foregroundColor: NSColor(rgb: palette.text)])
        for (index, target) in shown.enumerated() {
            drawnLabels.insert(target.label)
            let column = index / perColumn, row = index % perColumn
            let origin = CGPoint(x: panel.minX + CGFloat(column) * columnWidth + 12, y: panel.maxY - 36 - CGFloat(row + 1) * rowHeight)
            let primary = (visible.firstIndex(where: { $0.label == target.label }) ?? index).isMultiple(of: 2)
            let color = primary ? palette.control : palette.alternate
            let code = NSMutableAttributedString(string: target.label.uppercased(), attributes: [.font: font, .foregroundColor: NSColor(rgb: color)])
            if !prefix.isEmpty { code.addAttribute(.foregroundColor, value: NSColor(rgb: primary ? palette.typedControl : palette.typedAlternate), range: NSRange(location: 0, length: min(prefix.count, target.label.count))) }
            code.draw(at: origin)
            let raw = target.metadata.description.isEmpty ? target.metadata.title : target.metadata.description
            let caption = raw.isEmpty ? target.metadata.role.replacingOccurrences(of: "AX", with: "") : raw
            let style = NSMutableParagraphStyle(); style.lineBreakMode = .byTruncatingTail
            (caption as NSString).draw(in: CGRect(x: origin.x + codeWidth, y: origin.y, width: columnWidth - codeWidth - 24, height: ceil(fontSize) + 3), withAttributes: [.font: NSFont.systemFont(ofSize: max(12, fontSize - 2)), .foregroundColor: NSColor(rgb: palette.text), .paragraphStyle: style])
        }
        let footer = page.count > 1 ? "Page \(page.number + 1)/\(page.count) · ⇥ next · ⇧⇥ back" : "Type code · Esc dismisses"
        (footer as NSString).draw(at: CGPoint(x: panel.minX + 12, y: panel.minY + 9), withAttributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor(rgb: palette.text)])
    }

}
final class Overlays {
    private var panels: [NSPanel] = []
    func show(_ targets: [Target], prefix: String, fontSize: CGFloat, scopeFrame: CGRect? = nil, textFrames: [CGRect] = [], palette: ThemePalette = ThemePalette(theme: .glitch, dark: true), scopedPopup: Bool = false, ledgerPage: Int = 0) {
        hide()
        let top = NSScreen.screens.first?.frame.maxY ?? 0
        for screen in NSScreen.screens {
            let panel = NSPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.level = .init(rawValue: NSWindow.Level.popUpMenu.rawValue + 1)
            panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
            panel.hidesOnDeactivate = false
            panel.ignoresMouseEvents = true
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            let canvas = HintCanvas(frame: CGRect(origin: .zero, size: screen.frame.size))
            canvas.palette = palette
            canvas.scopedPopup = scopedPopup
            canvas.ledgerPage = ledgerPage
            canvas.scopeFrame = scopeFrame
            canvas.textFrames = textFrames
            canvas.targets = targets; canvas.prefix = prefix; canvas.fontSize = fontSize; canvas.screenFrame = screen.frame; canvas.desktopTop = top
            panel.contentView = canvas
            panel.orderFrontRegardless()
            // Resolve overflow before publishing the keyboard paging snapshot.
            canvas.display()
            panels.append(panel)
        }
    }
    var hasPagedChoices: Bool { panels.contains { ($0.contentView as? HintCanvas)?.usesLedger == true } }
    var visiblePanelCount: Int { panels.filter { $0.isVisible }.count }
    func hide() { panels.forEach { $0.orderOut(nil) }; panels.removeAll() }
}
