import AppKit
import OpenSesameCore
import OpenSesameBrand

private struct DrawnHint {
    let label: String
    var badge: CGRect
    let accent: NSColor
    let text: NSAttributedString
    let connector: NSBezierPath
    let caption: NSAttributedString?
    let isRegion: Bool
}

final class HintCanvas: NSView {
    var palette = ThemePalette(theme: .glitch, dark: true)
    var targets: [Target] = []
    var prefix = ""
    var fontSize: CGFloat = 16
    var screenFrame = CGRect.zero
    var desktopTop: CGFloat = 0
    var scopeFrame: CGRect?
    var windowFrame: CGRect?
    var appName = ""
    var owner: pid_t?
    var appIcon: NSImage?
    var textFrames: [CGRect] = []
    private(set) var drawnLabels = Set<String>()
    private(set) var localBadgeFrames: [String: CGRect] = [:]
    private(set) var usesLedger = false
    private(set) var ledgerPanelFrame: CGRect?
    private(set) var associatedLabels = Set<String>()
    private(set) var localLabels = Set<String>()
    private(set) var overflowLabels = Set<String>()
    private(set) var drawnAccents: [String: UInt32] = [:]
    private(set) var sectionOutlineAccents: [String: UInt32] = [:]
    private(set) var regionMarkerFrames: [String: CGRect] = [:]
    private(set) var ledgerHeading = ""
    private(set) var ledgerPageCount = 0
    private(set) var ledgerSourceKey = ""
    private(set) var ledgerCaptions: [String: String] = [:]
    private(set) var ledgerGroupDetails: [String: String] = [:]
    private func isRegion(_ target: Target) -> Bool { target.kind == .window || target.metadata.role == "OpenSesameSection" }
    private func local(_ frame: CGRect) -> CGRect {
        CGRect(x: frame.minX - screenFrame.minX, y: desktopTop - frame.maxY - screenFrame.minY, width: frame.width, height: frame.height)
    }
    private func regionFrame(_ target: Target) -> CGRect {
        let frame = local(target.frame)
        guard target.metadata.role == "OpenSesameSection" else { return frame }
        let neighbors = targets.filter { $0.metadata.role == "OpenSesameSection" && $0.label != target.label }.map { local($0.frame) }
        return RegionMarkerLayout.sectionFrame(frame, bounds: bounds, neighbors: neighbors)
    }
    private func colors(at index: Int) -> (accent: UInt32, typed: UInt32) {
        let target = targets[index]
        if isRegion(target) {
            let ordinal = targets[..<index].filter { isRegion($0) }.count
            return HintStyle.sectionColors(index: ordinal, palette: palette)
        }
        let ordinal = targets[..<index].filter { !isRegion($0) && $0.kind == target.kind }.count
        return HintStyle.colors(kind: target.kind, index: ordinal, palette: palette)
    }
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
        HintBorder.draw(in: rect, kind: .compact, cornerRadius: 10,
                        accent: NSColor(rgb: palette.text).withAlphaComponent(0.3), background: NSColor(rgb: palette.background))
    }
    var scopedPopup = false
    var prefersActionPanel = false
    var canGoBack = false
    var ledgerPage = 0
    override func draw(_ dirtyRect: NSRect) {
        drawnLabels.removeAll()
        localBadgeFrames.removeAll()
        usesLedger = false
        ledgerHeading = ""; ledgerCaptions = [:]; ledgerGroupDetails = [:]; ledgerPageCount = 0; ledgerSourceKey = ""
        ledgerPanelFrame = nil
        associatedLabels.removeAll()
        localLabels.removeAll(); overflowLabels.removeAll()
        drawnAccents.removeAll(); sectionOutlineAccents.removeAll(); regionMarkerFrames.removeAll()
        drawRegionOutlines()
        let forcedPanel = Set(targets.filter {
            prefersActionPanel && $0.kind != .window && $0.kind != .tab && $0.kind != .desktop && $0.metadata.role != "AXMenuBarItem"
        }.map(\.label))
        if forcedPanel.count == targets.count || (scopedPopup && targets.allSatisfy({ $0.metadata.role == "AXMenuItem" })) { drawGroupedLedger(items: targets, localized: false); return }
        var overflowTargets = targets.filter { forcedPanel.contains($0.label) }
        var overflowReservations: [CGRect] = []
        var occupied: [CGRect] = []
        var drawings: [DrawnHint] = []
        let font = HintTypography.compactCode(size: fontSize)
        let badgeTextSize = targets.map { ($0.label.uppercased() as NSString).size(withAttributes: [.font: font]) }
        let badgeSize = HintStyle.badgeSize(text: CGSize(width: badgeTextSize.map(\.width).max() ?? fontSize,
                                                        height: badgeTextSize.map(\.height).max() ?? fontSize))
        let controlRects = targets.flatMap { target -> [CGRect] in
            let frames = target.metadata.role == "OpenSesameSection" ? target.sectionMemberFrames : (target.kind == .window ? [] : [target.frame])
            return frames.map { frame in
                CGRect(x: frame.minX - screenFrame.minX, y: desktopTop - frame.maxY - screenFrame.minY,
                       width: frame.width, height: frame.height)
            }
        }
        let reportedSurface = scopeFrame.map { CGRect(x: $0.minX - screenFrame.minX, y: desktopTop - $0.maxY - screenFrame.minY, width: $0.width, height: $0.height) }
        let rowControls = targets.enumerated().compactMap { index, target -> CompactRowLayout.Control? in
            guard !forcedPanel.contains(target.label), target.metadata.role != "OpenSesameSection", target.kind == .control, ["AXButton", "AXRadioButton", "AXCheckBox"].contains(target.metadata.role) else { return nil }
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
            guard !forcedPanel.contains(target.label) else { continue }
            let region = isRegion(target)
            let global = CGRect(x: target.frame.minX, y: desktopTop - target.frame.maxY, width: target.frame.width, height: target.frame.height)
            let rect = region ? regionFrame(target) : global.offsetBy(dx: -screenFrame.minX, dy: -screenFrame.minY)
            guard rect.intersects(bounds) else { continue }
            let colors = colors(at: index)
            let accent = NSColor(rgb: colors.accent)
            let label = target.label.uppercased()
            // Keep the code compact: only close actions need an extra glyph.
            let text = (target.kind == .close ? "× " + label : label) as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: accent
            ]
            let styled = NSMutableAttributedString(string: text as String, attributes: attributes)
            let codeOffset = target.kind == .close ? 2 : 0
            if !prefix.isEmpty {
                let typedAccent = NSColor(rgb: colors.typed)
                styled.addAttribute(.foregroundColor, value: typedAccent,
                                    range: NSRange(location: codeOffset, length: prefix.count))
            }
            let isMenuBar = target.metadata.role == "AXMenuBarItem"
            // Use local geometry for controls and tabs in every app.
            let usesLocalPlacement = target.kind == .control || target.kind == .tab || (target.kind == .menu && !isMenuBar)
            let reservedRows = compact.filter { $0.key != index }.map { $0.value.reservation }
            let nearby = usesLocalPlacement && !region && target.kind != .tab && compact[index] == nil
                ? WidgetLayout.nearby(control: rect, badge: badgeSize, bounds: bounds, occupied: occupied + reservedRows,
                                      controls: controlRects, text: textObstacles) : nil
            let exteriorBadge = CGSize(width: max(badgeSize.width, min(200,
                ceil((shortCaption(target) as NSString).size(withAttributes: [.font: captionFont]).width) + 12)), height: badgeSize.height)
            let exterior = usesLocalPlacement && !region && target.kind != .tab && compact[index] == nil && nearby == nil
                ? WidgetLayout.exterior(control: rect, surface: localSurface ?? rect, badge: exteriorBadge, bounds: bounds,
                                        occupied: occupied + reservedRows, obstacles: controlRects + textObstacles, captionHeight: captionHeight) : nil
            let candidates: [CGRect]
            if region {
                let visible = target.metadata.visibleFrames.map { $0.map(local) } ?? [rect]
                candidates = RegionMarkerLayout.place(region: rect, visible: visible,
                    aspectRatio: BlockLettering.aspectRatio(for: target.label), fontSize: fontSize, bounds: bounds,
                    occupied: occupied + reservedRows).map { [$0] } ?? []
            } else if target.kind == .desktop {
                candidates = BadgeLayout.insideObject(control: rect, visible: target.metadata.visibleFrames?.map(local) ?? [rect],
                    badge: badgeSize, bounds: bounds, occupied: occupied + reservedRows).map { [$0] } ?? []
            } else if target.kind == .tab {
                candidates = BadgeLayout.insideTab(control: rect, badge: badgeSize,
                    textHeight: ceil(styled.size().height), bounds: bounds,
                    occupied: occupied + reservedRows + textObstacles + controlRects.filter { $0 != rect }).map { [$0] } ?? []
            } else if let placement = compact[index] {
                candidates = [placement.frame]
            } else if let nearby {
                candidates = [nearby]
            } else if usesLocalPlacement {
                candidates = exterior.map { [$0] } ?? []
            } else {
                candidates = BadgeLayout.candidates(control: rect, badge: badgeSize,
                                                   menuBar: isMenuBar, index: index, bounds: bounds)
            }
            guard let badge = BadgeLayout.place(candidates: candidates, bounds: bounds,
                occupied: occupied + reservedRows, controls: region || target.kind == .tab || target.kind == .desktop ? [] : controlRects,
                spacing: region ? 8 : (target.kind == .control ? 3 : 5)) else {
                overflowTargets.append(target)
                continue
            }
            occupied.append(compact[index].flatMap { $0.frame == badge ? $0.reservation : nil } ?? (exterior == badge ? badge.union(badge.offsetBy(dx: 0, dy: -captionHeight)) : badge))
            // Keep the full layout through overflow resolution. Filter only
            // after panel collisions and local/overflow membership are fixed.
            // One continuous path joins the target and badge, including any
            // local stagger. No detached ticks or diagonal connector segments.
            let anchorRect = rect
            let anchorX = min(max(badge.midX, anchorRect.minX + 1), anchorRect.maxX - 1)
            let anchor = CGPoint(x: anchorX, y: min(max(badge.midY, anchorRect.minY + 1), anchorRect.maxY - 1))
            let endpoint = CGPoint(x: min(max(anchor.x, badge.minX), badge.maxX),
                                   y: min(max(anchor.y, badge.minY), badge.maxY))
            let connector = NSBezierPath()
            let unnamed = shortCaption(target).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let detached = exterior == badge || (compact[index].map { $0.outsideSurface && badge == $0.frame } ?? false)
            if region || target.kind == .tab || target.kind == .desktop {
                // Spatial choices identify their own regions; tabs stay inline.
            } else if unnamed && detached && !isMenuBar {
                // A blank caption cannot identify an icon-only control. Keep
                // its leader and outline even in a shared exterior strip.
                connector.move(to: anchor)
                connector.line(to: CGPoint(x: anchor.x, y: endpoint.y))
                connector.line(to: endpoint)
                connector.append(NSBezierPath(roundedRect: rect, xRadius: 3, yRadius: 3))
                associatedLabels.insert(target.label)
            } else if let placement = compact[index], badge == placement.frame {
                // A single horizontal strip maps left to right to this control row.
            } else if let nearby, badge == nearby {
                connector.move(to: anchor)
                if abs(anchor.x - endpoint.x) > 0.5 && abs(anchor.y - endpoint.y) > 0.5 {
                    connector.line(to: CGPoint(x: anchor.x, y: endpoint.y))
                }
                connector.line(to: endpoint)
            } else if exterior != badge && !region {
                connector.move(to: anchor)
                if abs(anchor.x - endpoint.x) > 0.5 && abs(anchor.y - endpoint.y) > 0.5 {
                    connector.line(to: CGPoint(x: anchor.x, y: endpoint.y))
                }
                connector.line(to: endpoint)
            }
            // Menu-bar lanes already identify the item with a direct leader.
            // Metadata quality must not change its visual weight.
            if unnamed, !region, !isMenuBar, target.kind != .tab, target.kind != .desktop, !associatedLabels.contains(target.label) {
                connector.append(NSBezierPath(roundedRect: rect, xRadius: 3, yRadius: 3))
                associatedLabels.insert(target.label)
            }
            var caption: NSAttributedString?
            if (compact[index].map { $0.outsideSurface && badge == $0.frame } ?? false) || exterior == badge {
                caption = NSAttributedString(string: shortCaption(target), attributes: [.font: captionFont, .foregroundColor: NSColor(rgb: palette.text)])
            }
            drawings.append(DrawnHint(label: target.label, badge: badge, accent: accent, text: styled, connector: connector, caption: caption, isRegion: region))
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
                overflowReservations = reservations
                let panels = ledgerGroups(overflowTargets).map { ledgerGeometry(for: $0, avoid: reservations).panel }
                // A panel may cover a window's first marker placement while
                // leaving ample exposed window space beside it. Try that space
                // before moving the window choice into a later overflow page.
                // Keep these panel reservations through drawing and filtering.
                for index in drawings.indices {
                    let drawing = drawings[index]
                    guard drawing.isRegion, !missing.contains(drawing.label),
                          let target = targets.first(where: { $0.label == drawing.label && $0.kind == .window }),
                          panels.contains(where: { $0.insetBy(dx: -5, dy: -5).intersects(drawing.badge) }) else { continue }
                    let others = drawings.enumerated().filter { $0.offset != index && !missing.contains($0.element.label) }.map { _, other in
                        other.caption == nil ? other.badge : other.badge.union(other.badge.offsetBy(dx: 0, dy: -captionHeight))
                    }
                    let frame = regionFrame(target)
                    if let marker = RegionMarkerLayout.place(region: frame,
                        visible: target.metadata.visibleFrames?.map(local) ?? [frame],
                        aspectRatio: BlockLettering.aspectRatio(for: target.label), fontSize: fontSize,
                        bounds: bounds, occupied: others + panels) {
                        drawings[index].badge = marker
                    }
                }
                let covered = drawings.filter { drawing in
                    let reservation = drawing.caption == nil ? drawing.badge
                        : drawing.badge.union(drawing.badge.offsetBy(dx: 0, dy: -captionHeight))
                    return panels.contains { $0.insetBy(dx: -5, dy: -5).intersects(reservation) }
                }.map(\.label)
                let before = missing.count
                missing.formUnion(covered)
                if missing.count == before { break }
            }
            overflowTargets = targets.filter { missing.contains($0.label) }
            overflowLabels = missing
            drawings.removeAll { missing.contains($0.label) }

        }
        drawings.removeAll { !$0.label.hasPrefix(prefix) }
        associatedLabels.formIntersection(drawings.map(\.label))
        drawnLabels = Set(drawings.map(\.label))
        localLabels = drawnLabels
        localBadgeFrames = Dictionary(uniqueKeysWithValues: drawings.map { ($0.label, $0.badge) })
        regionMarkerFrames = Dictionary(uniqueKeysWithValues: drawings.filter(\.isRegion).map { ($0.label, $0.badge) })
        for (index, target) in targets.enumerated() where localLabels.contains(target.label) {
            drawnAccents[target.label] = colors(at: index).accent
        }
        // Connectors form a background layer. A later target's line must never
        // draw across the code on an earlier badge.
        for drawing in drawings {
            drawing.accent.setStroke()
            drawing.connector.lineWidth = HintStyle.connectorLineWidth
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
            if drawing.isRegion {
                BlockLettering.draw(drawing.label, in: drawing.badge, accent: drawing.accent,
                    typed: NSColor(rgb: palette.text), prefixLength: prefix.count, background: NSColor(rgb: palette.background))
                continue
            }
            if drawing.caption == nil {
                NSColor(rgb: palette.background).setFill()
                let plate = NSBezierPath(roundedRect: drawing.badge, xRadius: HintStyle.cornerRadius, yRadius: HintStyle.cornerRadius)
                plate.fill()
                HintBorder.draw(in: drawing.badge, kind: .compact, cornerRadius: HintStyle.cornerRadius,
                    accent: drawing.accent, background: NSColor(rgb: palette.background))
            }
            if let caption = drawing.caption {
                let captionRect = CGRect(x: drawing.badge.minX - 2, y: drawing.badge.minY - captionHeight,
                                         width: drawing.badge.width + 4, height: captionHeight)
                let style = NSMutableParagraphStyle(); style.alignment = .center; style.lineBreakMode = .byTruncatingTail
                let styledCaption = NSMutableAttributedString(attributedString: caption)
                styledCaption.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: styledCaption.length))
                styledCaption.draw(in: captionRect)
            }
            drawing.text.draw(at: CGPoint(x: drawing.caption == nil ? drawing.badge.minX + HintStyle.horizontalPadding : drawing.badge.midX - drawing.text.size().width / 2,
                                         y: drawing.badge.midY - drawing.text.size().height / 2))
        }
        if !overflowTargets.isEmpty { drawGroupedLedger(items: overflowTargets, localized: true, avoid: overflowReservations) }
    }
    private func drawRegionOutlines() {
        for (index, target) in targets.enumerated() where isRegion(target) && target.label.hasPrefix(prefix) {
            let rect = regionFrame(target)
            guard rect.intersects(bounds) else { continue }
            let accent = colors(at: index).accent
            sectionOutlineAccents[target.label] = accent
            NSGraphicsContext.saveGraphicsState()
            if let visible = target.metadata.visibleFrames {
                let clip = NSBezierPath()
                for frame in visible { clip.appendRect(local(frame)) }
                clip.addClip()
            }
            HintBorder.draw(in: rect, kind: .region, accent: NSColor(rgb: accent), background: NSColor(rgb: palette.background))
            NSGraphicsContext.restoreGraphicsState()
        }
    }
    private func ledgerGroups(_ items: [Target]) -> [[Target]] {
        var keys: [String] = []
        var groups: [String: [Target]] = [:]
        for target in items where local(target.frame).intersects(bounds) {
            let key = TargetPresentation.sourceKey(target)
            if groups[key] == nil { keys.append(key) }
            groups[key, default: []].append(target)
        }
        // The active app comes first; desktop and other owners never share its
        // page. A single visible panel avoids competing lists across the screen.
        let foreground = owner.flatMap { pid in items.first { $0.kind != .desktop && $0.metadata.owner == pid } }
            ?? items.first { $0.kind != .desktop && $0.kind != .window }
        if let foreground, let index = keys.firstIndex(of: TargetPresentation.sourceKey(foreground)) {
            keys.insert(keys.remove(at: index), at: 0)
        }
        return keys.compactMap { groups[$0] }
    }
    private func drawGroupedLedger(items: [Target], localized: Bool, avoid: [CGRect] = []) {
        let groups = ledgerGroups(items).filter { $0.contains { $0.label.hasPrefix(prefix) } }
        let counts = groups.map { ledgerGeometry(for: $0, avoid: avoid).count }
        let count = counts.reduce(0, +)
        guard count > 0 else { return }
        let number = ((ledgerPage % count) + count) % count
        var offset = 0
        for (group, pages) in zip(groups, counts) {
            if number < offset + pages {
                let page = ledgerGeometry(for: group, avoid: avoid, requestedPage: number - offset)
                drawLedger(items: group, localized: localized, page: page, number: number, count: count)
                return
            }
            offset += pages
        }
    }
    private func ledgerGeometry(for visible: [Target], avoid: [CGRect] = [], requestedPage: Int = 0) -> LedgerPage {
        let local: (CGRect) -> CGRect = { frame in
            CGRect(x: frame.minX - self.screenFrame.minX, y: self.desktopTop - frame.maxY - self.screenFrame.minY, width: frame.width, height: frame.height)
        }
        let controls = visible.map { local($0.frame) }
        let source = visible.first!
        let belongsToWindow = source.kind != .desktop && (owner == nil || source.metadata.owner == owner)
        let focus = (belongsToWindow ? scopeFrame.map(local) : nil) ?? controls.reduce(CGRect.null) { $0.union($1) }
        let surface = (belongsToWindow ? (scopedPopup ? scopeFrame.map(local) : windowFrame.map(local)) : nil) ?? focus
        let font = HintTypography.compactCode(size: fontSize)
        let codeWidth = ceil((String(repeating: "M", count: visible.map(\.label.count).max() ?? 2) as NSString).size(withAttributes: [.font: font]).width) + 12
        return LedgerPage(items: visible.filter { $0.label.hasPrefix(prefix) }.count, layoutItems: visible.count, requestedPage: requestedPage,
                          bounds: bounds, surface: surface, fontSize: fontSize, codeWidth: codeWidth, avoid: avoid, focus: focus)
    }
    private func drawLedger(items visible: [Target], localized: Bool, page: LedgerPage, number: Int, count: Int) {
        let matching = visible.filter { $0.label.hasPrefix(prefix) }
        guard !matching.isEmpty else { return }
        usesLedger = true
        let font = HintTypography.compactCode(size: fontSize)
        let codeWidth = ceil((String(repeating: "M", count: visible.map(\.label.count).max() ?? 2) as NSString).size(withAttributes: [.font: font]).width) + 12
        let shown = Array(matching[page.range])
        let panel = page.panel, rowHeight = page.rowHeight, columnWidth = page.columnWidth
        let perColumn = page.rowsPerColumn
        ledgerPanelFrame = panel
        drawPanel(panel)
        // Use unfiltered membership so typing never changes ownership or layout.
        ledgerPageCount = count
        ledgerSourceKey = TargetPresentation.sourceKey(visible[0])
        let sourceName = TargetPresentation.sourceName(visible[0], fallback: appName)
        let heading = (sourceName.isEmpty ? "" : sourceName + " · ") + (localized ? "More controls" : "Controls")
        ledgerHeading = heading
        let headerIcon = (visible[0].kind == .desktop ? NSImage(systemSymbolName: "desktopcomputer", accessibilityDescription: nil)?.withSymbolConfiguration(.init(paletteColors: [NSColor(rgb: palette.text)])) : AppIdentity.icon(bundleID: visible[0].metadata.bundleID))
        let inset: CGFloat = headerIcon == nil ? 12 : 36
        headerIcon?.draw(in: CGRect(x: panel.minX + 12, y: panel.maxY - 28, width: 18, height: 18))
        let headingStyle = NSMutableParagraphStyle(); headingStyle.lineBreakMode = .byTruncatingTail
        (heading as NSString).draw(in: CGRect(x: panel.minX + inset, y: panel.maxY - 28, width: panel.width - inset - 12, height: 18),
            withAttributes: [.font: NSFont.systemFont(ofSize: 12, weight: .semibold), .foregroundColor: NSColor(rgb: palette.text), .paragraphStyle: headingStyle])
        for (index, target) in shown.enumerated() {
            drawnLabels.insert(target.label)
            let column = index / perColumn, row = index % perColumn
            let origin = CGPoint(x: panel.minX + CGFloat(column) * columnWidth + 12, y: panel.maxY - 36 - CGFloat(row + 1) * rowHeight)
            let originalIndex = targets.firstIndex(where: { $0.label == target.label }) ?? index
            let colors = colors(at: originalIndex)
            let color = colors.accent
            drawnAccents[target.label] = color
            let code = NSMutableAttributedString(string: target.label.uppercased(), attributes: [.font: font, .foregroundColor: NSColor(rgb: color)])
            if !prefix.isEmpty { code.addAttribute(.foregroundColor, value: NSColor(rgb: colors.typed), range: NSRange(location: 0, length: min(prefix.count, target.label.count))) }
            let centerY = origin.y + rowHeight / 2
            code.draw(at: CGPoint(x: origin.x, y: centerY - code.size().height / 2))
            let group = TargetPresentation.tabGroup(target)
            let caption = group?.title ?? TargetPresentation.caption(target)
            ledgerCaptions[target.label] = caption
            let iconSize: CGFloat = group == nil ? 16 : 20
            let iconColor = NSColor(rgb: group == nil ? palette.text : color)
            TargetPresentation.icon(target, foreground: iconColor).draw(in:
                CGRect(x: origin.x + codeWidth + (16 - iconSize) / 2, y: centerY - iconSize / 2, width: iconSize, height: iconSize))
            let textWidth = columnWidth - codeWidth - 48
            let textX = origin.x + codeWidth + 24
            if let group {
                ledgerGroupDetails[target.label] = group.detail
                let style = NSMutableParagraphStyle(); style.lineBreakMode = .byTruncatingTail
                let titleFont = NSFont.systemFont(ofSize: max(13, fontSize - 1), weight: .semibold)
                let detailFont = NSFont.systemFont(ofSize: max(11, fontSize - 4))
                let titleHeight = ceil(titleFont.ascender - titleFont.descender + titleFont.leading)
                let detailHeight = ceil(detailFont.ascender - detailFont.descender + detailFont.leading)
                let bottom = centerY - (titleHeight + detailHeight + 2) / 2
                (caption as NSString).draw(in: CGRect(x: textX, y: bottom + detailHeight + 2, width: textWidth, height: titleHeight),
                    withAttributes: [.font: titleFont, .foregroundColor: NSColor(rgb: palette.text), .paragraphStyle: style])
                (group.detail as NSString).draw(in: CGRect(x: textX, y: bottom, width: textWidth, height: detailHeight),
                    withAttributes: [.font: detailFont, .foregroundColor: NSColor(rgb: palette.text).withAlphaComponent(0.8), .paragraphStyle: style])
                continue
            }
            let style = NSMutableParagraphStyle(); style.lineBreakMode = .byWordWrapping
            let text = NSAttributedString(string: caption, attributes: [.font: NSFont.systemFont(ofSize: max(12, fontSize - 2)), .foregroundColor: NSColor(rgb: palette.text), .paragraphStyle: style])
            let textHeight = min(rowHeight - 8, ceil(text.boundingRect(with: CGSize(width: textWidth, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin]).height))
            text.draw(with: CGRect(x: textX, y: centerY - textHeight / 2, width: textWidth, height: textHeight),
                      options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])
        }
        let footer = count > 1 ? "Page \(number + 1)/\(count) · ⇥ next · ⇧⇥ back"
            : (canGoBack ? "Type code · ⌫ up · Esc dismisses" : "Type code · Esc dismisses")
        (footer as NSString).draw(at: CGPoint(x: panel.minX + 12, y: panel.minY + 9), withAttributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor(rgb: palette.text)])
    }

}
final class Overlays {
    private var panels: [NSPanel] = []
    func show(_ targets: [Target], prefix: String, fontSize: CGFloat, scopeFrame: CGRect? = nil, textFrames: [CGRect] = [], palette: ThemePalette = ThemePalette(theme: .glitch, dark: true), scopedPopup: Bool = false, ledgerPage: Int = 0, prefersActionPanel: Bool = false, canGoBack: Bool = false, windowFrame: CGRect? = nil, appName: String = "", appIcon: NSImage? = nil, owner: pid_t? = nil) {
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
            canvas.prefersActionPanel = prefersActionPanel
            canvas.canGoBack = canGoBack
            canvas.ledgerPage = ledgerPage
            canvas.scopeFrame = scopeFrame
            canvas.windowFrame = windowFrame
            canvas.appName = appName; canvas.appIcon = appIcon; canvas.owner = owner
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
