import CoreGraphics
import Testing
import OpenSesameBrand

@Test func establishedWordmarkLettersStayExactlyTheSame() {
    let expected: [Character: [String]] = [
        "O": ["█▀█", "█▄█"], "P": ["█▀█", "█▀▀"], "E": ["█▀▀", "██▄"],
        "N": ["█▄░█", "█░▀█"], "S": ["█▀", "▄█"], "A": ["█▀█", "█▀█"], "M": ["█▄ ▄█", "█░▀░█"]
    ]
    for (letter, rows) in expected { #expect(BlockLettering.glyphs[letter] == rows) }
}

@Test func completeHintAlphabetUsesDistinctGlyphsOnTheSameBlockGrid() {
    let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
    #expect(Set(BlockLettering.glyphs.keys) == Set(alphabet + Array("12345")))
    #expect(Set(alphabet.map { BlockLettering.glyphs[$0]!.joined(separator: "\n") }).count == 26)
    for letter in alphabet {
        let code = String(letter)
        let rect = CGRect(x: 0, y: 0, width: BlockLettering.aspectRatio(for: code) * 64, height: 64)
        let cells = BlockLettering.cells(for: code, in: rect)
        #expect(!cells.isEmpty)
        #expect(cells.allSatisfy { rect.contains($0.frame) && $0.frame.width == 12 && [16, 32].contains($0.frame.height) })
    }
}

@Test func stackNumbersUseTheSameBlockGridAndRemainDistinct() {
    let digits = Array("12345")
    #expect(Set(digits.map { BlockLettering.glyphs[$0]!.joined() }).count == 5)
    for digit in digits {
        let rect = CGRect(x: 0, y: 0, width: CGFloat(BlockLettering.columns(for: String(digit))) * 12, height: 64)
        let cells = BlockLettering.cells(for: String(digit), in: rect)
        #expect(!cells.isEmpty && cells.allSatisfy { rect.contains($0.frame) && $0.frame.width == 12 && [16, 32].contains($0.frame.height) })
    }
}
