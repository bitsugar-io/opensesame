import Testing
@testable import OpenSesameCore
@Test func codesStayUniqueAndPrefixFree() {
    for count in [0, 1, 26, 27, 676, 677, 2000] {
        let labels = Hints.labels(count: count)
        #expect(labels.count == count)
        #expect(Set(labels).count == count)
        #expect(Set(labels.map(\.count)).count <= 1)
        #expect(labels.allSatisfy { $0.allSatisfy { Hints.alphabet.contains($0) } })
    }
}
@Test func appFilters() {
    #expect(!Hints.allows(bundleID: "com.apple.Safari", name: "Safari", list: ["safari"], only: false))
    #expect(Hints.allows(bundleID: "com.apple.Safari", name: "Safari", list: ["COM.APPLE.SAFARI"], only: true))
    #expect(!Hints.allows(bundleID: "x", name: "X", list: [], only: true))
    #expect(Hints.allows(bundleID: "x", name: "X", list: [], only: false))
}

@Test func hintLettersAcceptDisplayedUppercase() {
    for letter in Hints.alphabet {
        #expect(Hints.letter(String(letter)) == String(letter))
        #expect(Hints.letter(String(letter).uppercased()) == String(letter))
    }
    for invalid in ["", " ", "\u{1b}", "\u{1}", "ab", "1", "é"] {
        #expect(Hints.letter(invalid) == nil)
    }
}

@Test func twoLetterHintsWaitForSecondLetter() {
    let labels = Hints.labels(count: 40)
    let first = Hints.matches(prefix: "a", labels: labels)
    #expect(first.count > 1)
    #expect(!first.contains("a"))
    #expect(Hints.matches(prefix: "as", labels: labels) == ["as"])
    #expect(Hints.matches(prefix: "zz", labels: labels).isEmpty)
}

@Test func evenSmallHintSetsRequireTwoLetters() {
    let capacity = HintConfiguration.defaultAlphabet.count * HintConfiguration.defaultAlphabet.count
    for count in [1, 2, 10, 26, 27, capacity] {
        #expect(Hints.labels(count: count).allSatisfy { $0.count == 2 })
    }
    #expect(Hints.labels(count: capacity + 1).allSatisfy { $0.count == 3 })
}
