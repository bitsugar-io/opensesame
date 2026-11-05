/// Chromium advertises AXPress on structural nodes too. A press action alone
/// does not turn every DOM wrapper or text leaf into a useful hint target.
public enum WebTargetPolicy {
    public static func allows(role: String, insideWebContent: Bool) -> Bool {
        guard insideWebContent else { return true }
        return ["AXButton", "AXCheckBox", "AXRadioButton", "AXSwitch", "AXLink", "AXPopUpButton", "AXMenuButton", "AXComboBox", "AXTextField", "AXTextArea", "AXSearchField", "AXSlider", "AXIncrementor", "AXDisclosureTriangle", "AXMenuItem", "AXTab"].contains(role)
    }
}
