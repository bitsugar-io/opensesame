import SwiftUI
import OpenSesameCore
import OpenSesameBrand

/// Preview codes keep the live badge font size. Stack them when a complete
/// row cannot fit; never truncate or squeeze the code to preserve a row.
struct HintSamples: View {
    let samples: [(code: String, accent: UInt32, typed: UInt32)]
    let fontSize: CGFloat
    let background: UInt32
    var prefixLength = 0

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { badges }.fixedSize(horizontal: true, vertical: false)
            VStack(alignment: .leading, spacing: 8) { badges }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private var badges: some View {
        ForEach(samples.indices, id: \.self) { index in
            let sample = samples[index]
            let color = Color(nsColor: NSColor(rgb: sample.accent))
            (Text(String(sample.code.prefix(prefixLength))).foregroundColor(Color(nsColor: NSColor(rgb: sample.typed))) +
             Text(String(sample.code.dropFirst(prefixLength))).foregroundColor(color))
                .font(Font(HintTypography.compactCode(size: fontSize)))
                .padding(.horizontal, HintStyle.horizontalPadding)
                .padding(.vertical, HintStyle.verticalPadding)
                .background(Color(nsColor: NSColor(rgb: background)), in: RoundedRectangle(cornerRadius: HintStyle.cornerRadius))
                .overlay(RoundedRectangle(cornerRadius: HintStyle.cornerRadius).strokeBorder(color.opacity(HintStyle.borderOpacity), lineWidth: HintStyle.borderLineWidth))
                .fixedSize()
        }
    }
}

struct RegionHintSamples: NSViewRepresentable {
    let codes: [String]
    let palette: ThemePalette
    let fontSize: CGFloat
    func makeNSView(context: Context) -> RegionSamplesCanvas { RegionSamplesCanvas() }
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: RegionSamplesCanvas, context: Context) -> CGSize? {
        let width = proposal.width ?? 328
        return CGSize(width: width, height: RegionSamplesCanvas.height(codes: codes, fontSize: fontSize, width: width))
    }
    func updateNSView(_ view: RegionSamplesCanvas, context: Context) {
        view.codes = codes; view.palette = palette; view.fontSize = fontSize; view.needsDisplay = true
        view.setAccessibilityElement(true)
        view.setAccessibilityRole(.image)
        view.setAccessibilityLabel("Window and section hint examples: " + codes.joined(separator: ", "))
    }
}

final class RegionSamplesCanvas: NSView {
    var codes: [String] = []
    var palette = ThemePalette(theme: .glitch, dark: true)
    var fontSize: CGFloat = 16
    private static func stacks(codes: [String], fontSize: CGFloat, width: CGFloat) -> Bool {
        let column = (width - CGFloat(max(0, codes.count - 1)) * 8) / CGFloat(max(1, codes.count))
        return codes.contains { BlockLettering.aspectRatio(for: $0) * max(48, min(64, fontSize * 4)) + 24 > column }
    }
    static func height(codes: [String], fontSize: CGFloat, width: CGFloat) -> CGFloat {
        stacks(codes: codes, fontSize: fontSize, width: width) ? CGFloat(codes.count) * 96 - 8 : 88
    }
    override func draw(_ dirtyRect: NSRect) {
        let count = CGFloat(max(1, codes.count))
        let stacked = Self.stacks(codes: codes, fontSize: fontSize, width: bounds.width)
        let width = stacked ? bounds.width : (bounds.width - 8 * (count - 1)) / count
        for (index, code) in codes.enumerated() {
            let rect = CGRect(x: stacked ? 0 : CGFloat(index) * (width + 8),
                y: stacked ? bounds.height - CGFloat(index + 1) * 96 + 8 : 0, width: width, height: 88)
            let accent = NSColor(rgb: HintStyle.sectionColors(index: index, palette: palette).accent)
            HintBorder.draw(in: rect, kind: .region, accent: accent, background: NSColor(rgb: palette.background))
            if let marker = RegionMarkerLayout.place(region: rect, visible: [rect], aspectRatio: BlockLettering.aspectRatio(for: code),
                fontSize: fontSize, bounds: bounds, occupied: []) {
                BlockLettering.draw(code, in: marker, accent: accent, typed: NSColor(rgb: palette.text), prefixLength: 0,
                    background: NSColor(rgb: palette.background))
            }
        }
    }
}
