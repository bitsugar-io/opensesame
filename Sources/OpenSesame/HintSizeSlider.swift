import AppKit
import SwiftUI

/// Draw the scale from the native thumb geometry, including its end insets.
struct HintSizeSlider: NSViewRepresentable {
    @Binding var value: Double
    let presets: [Int]
    let markerColor: NSColor
    let accentColor: NSColor
    let onCommit: () -> Void

    func makeNSView(context: Context) -> HintSizeSliderView { HintSizeSliderView() }

    func updateNSView(_ view: HintSizeSliderView, context: Context) {
        let slider = view.slider
        slider.doubleValue = min(max(value, 10), 22)
        slider.isEnabled = context.environment.isEnabled
        slider.accentColor = accentColor
        slider.needsDisplay = true
        slider.onChange = { rawValue in
            let stepped = Int(rawValue.rounded())
            let nearest = presets.min { abs($0 - stepped) < abs($1 - stepped) }
            let snapped = nearest.flatMap { abs(Double($0) - rawValue) <= 0.6 ? $0 : nil } ?? stepped
            value = Double(snapped)
            return Double(snapped)
        }
        slider.onCommit = onCommit
        view.presets = presets
        view.markerColor = markerColor
        view.needsDisplay = true
    }
}

final class HintSizeSliderView: NSView {
    let slider = MarkedHintSizeSlider()
    // Never use the live cell to measure other values: during a drag AppKit
    // caches its tracking geometry, and writes can interfere with that state.
    private let measuringSlider = NSSlider()
    var presets: [Int] = []
    var markerColor = NSColor.white
    override var isFlipped: Bool { true }
    override var intrinsicContentSize: NSSize { NSSize(width: NSView.noIntrinsicMetric, height: 54) }

    override init(frame: NSRect) {
        super.init(frame: frame)
        slider.minValue = 10
        slider.maxValue = 22
        slider.numberOfTickMarks = 0
        measuringSlider.minValue = 10
        measuringSlider.maxValue = 22
        measuringSlider.numberOfTickMarks = 0
        slider.isContinuous = true
        slider.target = slider
        slider.action = #selector(MarkedHintSizeSlider.changed)
        slider.setAccessibilityLabel("Hint size in points")
        slider.toolTip = "Snaps to the mint size presets. Use arrow keys for one-point adjustments."
        addSubview(slider)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        slider.frame = NSRect(x: 0, y: 0, width: bounds.width, height: 20)
        measuringSlider.frame = slider.bounds
        measuringSlider.controlSize = slider.controlSize
        measuringSlider.userInterfaceLayoutDirection = slider.userInterfaceLayoutDirection
        needsDisplay = true
    }

    func markerX(for value: Int) -> CGFloat {
        measuredThumbRect(for: Double(value)).midX
    }

    func measuredThumbRect(for value: Double) -> NSRect {
        guard let cell = measuringSlider.cell as? NSSliderCell else { return .zero }
        cell.doubleValue = value
        // AppKit establishes the bar geometry before drawing the knob.
        _ = cell.barRect(flipped: measuringSlider.isFlipped)
        return slider.convert(cell.knobRect(flipped: measuringSlider.isFlipped), to: self)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        for value in 10...22 {
            let major = presets.contains(value)
            let x = markerX(for: value)
            let width: CGFloat = major ? 2 : 1
            let rect = NSRect(x: x - width / 2, y: 25, width: width, height: major ? 12 : 4)
            (major ? markerColor : NSColor.secondaryLabelColor.withAlphaComponent(0.5)).setFill()
            NSBezierPath(roundedRect: rect, xRadius: width / 2, yRadius: width / 2).fill()
            guard major || value == 10 || value == 22 else { continue }
            let text = "\(value)" as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 10, weight: major ? .semibold : .medium),
                .foregroundColor: major ? markerColor : NSColor.secondaryLabelColor,
            ]
            let size = text.size(withAttributes: attributes)
            let labelX = max(0, min(x - size.width / 2, bounds.width - size.width))
            text.draw(at: NSPoint(x: labelX, y: 40), withAttributes: attributes)
        }
    }
}

final class MarkedHintSizeSlider: NSSlider {
    var onChange: ((Double) -> Double)?
    var onCommit: (() -> Void)?
    var accentColor = NSColor.systemPurple

    var displayedThumbRect: NSRect {
        if let scale = superview as? HintSizeSliderView {
            return convert(scale.measuredThumbRect(for: doubleValue), from: scale)
        }
        return (cell as? NSSliderCell)?.knobRect(flipped: isFlipped) ?? .zero
    }

    override func draw(_ dirtyRect: NSRect) {
        // Preserve native tracking, keyboard control and accessibility, while
        // drawing our own colors instead of the system accent-colored track.
        guard let cell = cell as? NSSliderCell else { return }
        let track = cell.barRect(flipped: isFlipped)
        // Use the snapped value for painting, even while AppKit caches the raw
        // pointer position during native mouse tracking.
        let knob = displayedThumbRect
        let opacity: CGFloat = isEnabled ? 1 : 0.35
        NSColor.labelColor.withAlphaComponent(0.12 * opacity).setFill()
        NSBezierPath(roundedRect: track, xRadius: track.height / 2, yRadius: track.height / 2).fill()
        let filled = NSRect(x: track.minX, y: track.minY,
                            width: max(0, min(track.width, knob.midX - track.minX)), height: track.height)
        accentColor.withAlphaComponent(opacity).setFill()
        NSBezierPath(roundedRect: filled, xRadius: track.height / 2, yRadius: track.height / 2).fill()
        let diameter = min(knob.width, knob.height)
        let thumb = NSRect(x: knob.midX - diameter / 2, y: knob.midY - diameter / 2,
                           width: diameter, height: diameter)
        NSColor.controlBackgroundColor.withAlphaComponent(opacity).setFill()
        NSBezierPath(ovalIn: thumb).fill()
        NSColor.secondaryLabelColor.withAlphaComponent(0.35 * opacity).setStroke()
        NSBezierPath(ovalIn: thumb).stroke()
    }

    @objc func changed() {
        doubleValue = onChange?(doubleValue) ?? doubleValue
        if NSApp.currentEvent?.type == .keyDown { onCommit?() }
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        onCommit?()
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 123, 125: _ = accessibilityPerformDecrement()
        case 124, 126: _ = accessibilityPerformIncrement()
        default: super.keyDown(with: event)
        }
    }

    override func accessibilityPerformIncrement() -> Bool {
        doubleValue = min(maxValue, doubleValue + 1)
        changed()
        onCommit?()
        return true
    }

    override func accessibilityPerformDecrement() -> Bool {
        doubleValue = max(minValue, doubleValue - 1)
        changed()
        onCommit?()
        return true
    }
}
