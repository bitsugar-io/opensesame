import Testing
@testable import OpenSesameCore

@Test func configuredCodesGrowWithoutPrefixCollisions() throws {
    for length in 1...3 {
        let config = try HintConfiguration(minimumLength: length, alphabet: "asdf", prefix: "g")
        for count in [1, 4, 5, 64, 65, 2000] {
            let labels = Hints.labels(count: count, configuration: config)
            #expect(Set(labels).count == count)
            #expect(Set(labels.map(\.count)).count == 1)
            #expect(labels.allSatisfy { $0.hasPrefix("g") && $0.count >= length + 1 })
            #expect(labels.allSatisfy { label in labels.filter { $0.hasPrefix(label) }.count == 1 })
        }
    }
}
@Test func invalidHintSettingsAreRejectedRatherThanProducingAmbiguousCodes() {
    for alphabet in ["", "a", "aa", "aA", "as df", "123", "a🙂"] {
        #expect(throws: HintConfiguration.ValidationError.self) { try HintConfiguration(alphabet: alphabet) }
    }
    for prefix in ["abcd", "g ", "⌘"] {
        #expect(throws: HintConfiguration.ValidationError.self) { try HintConfiguration(prefix: prefix) }
    }
    #expect(throws: HintConfiguration.ValidationError.self) { try HintConfiguration(minimumLength: 0) }
}
@Test func hintPreferencesAcceptUppercaseAndPreserveAlphabetOrder() throws {
    let config = try HintConfiguration(minimumLength: 1, alphabet: "JKLA", prefix: "G")
    #expect(Hints.labels(count: 4, configuration: config) == ["gj", "gk", "gl", "ga"])
}
