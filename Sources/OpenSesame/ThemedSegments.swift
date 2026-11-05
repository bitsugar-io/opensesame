import SwiftUI
import OpenSesameCore

struct ThemedSegments<Selection: Hashable>: View {
    @Binding var selection: Selection
    let options: [(Selection, String)]
    let palette: ThemePalette
    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                Button { selection = option.0 } label: {
                    Text(option.1).font(.system(size: 11, weight: .medium))
                        .frame(maxWidth: .infinity).padding(.vertical, 6)
                        .foregroundStyle(Color(nsColor: NSColor(rgb: palette.text)))
                        .background(Color(nsColor: NSColor(rgb: selection == option.0 ? palette.surface : palette.background)), in: RoundedRectangle(cornerRadius: 5))
                        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(selection == option.0 ? Color(nsColor: NSColor(rgb: palette.control)).opacity(0.5) : .clear))
                }.buttonStyle(.plain).accessibilityAddTraits(selection == option.0 ? .isSelected : [])
            }
        }.padding(3).background(Color(nsColor: NSColor(rgb: palette.background)), in: RoundedRectangle(cornerRadius: 7))
    }
}
