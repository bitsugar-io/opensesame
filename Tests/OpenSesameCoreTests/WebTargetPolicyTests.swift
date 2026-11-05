import Testing
@testable import OpenSesameCore

@Test func chromiumContainersAndTextAreNotIndependentActions() {
    for role in ["AXWebArea", "AXGroup", "AXStaticText", "AXImage", "AXHeading", "AXList", "AXTable", "AXColumn", "AXRow", "AXCell"] {
        #expect(!WebTargetPolicy.allows(role: role, insideWebContent: true))
    }
    for role in ["AXButton", "AXLink", "AXCheckBox", "AXRadioButton", "AXPopUpButton", "AXComboBox", "AXTextField", "AXSlider"] {
        #expect(WebTargetPolicy.allows(role: role, insideWebContent: true))
    }
    #expect(WebTargetPolicy.allows(role: "AXGroup", insideWebContent: false))
}
@Test func readableDefaultAvoidsAmbiguousLetterPairsWithoutRestrictingCustomSets() throws {
    #expect(HintConfiguration.defaultAlphabet == "sadfjklewcmpgh")
    #expect(!HintConfiguration.defaultAlphabet.contains("v"))
    #expect(!HintConfiguration.defaultAlphabet.contains("y"))
    #expect(try HintConfiguration(alphabet: "avy").alphabet == "avy")
}
