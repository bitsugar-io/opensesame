public enum MenuTraversal {
    // Plain native menu rows remain leaves. Custom rows can also contain
    // independent controls; only explicit controls and their containers qualify.
    public static func allowsEmbedded(role: String) -> Bool {
        ["AXGroup", "AXButton", "AXCheckBox", "AXRadioButton", "AXSwitch", "AXSlider", "AXPopUpButton", "AXMenuButton"].contains(role)
    }
    public static func descendsInto(role: String) -> Bool {
        role != "AXMenuItem" && role != "AXMenuBarItem"
    }
}
