import Testing
@testable import OpenSesameCore

@Test func tabGroupsLeadWithTheNameInsteadOfChildTabDescriptions() {
    let collapsed = TabGroupCaption(" group Hardware - 7 Tabs, • First website, • Second website, + 5 More - Collapsed")
    #expect(collapsed.title == "Hardware")
    #expect(collapsed.detail == "7 tabs · Collapsed")
    let expanded = TabGroupCaption("group Research - Notes - 1 Tab, • A long website title - Expanded")
    #expect(expanded.title == "Research - Notes")
    #expect(expanded.detail == "1 tab · Expanded")
    #expect(TabGroupCaption("group Empty - 0 Tabs - Collapsed").detail == "0 tabs · Collapsed")
}

@Test func unfamiliarGroupLabelsKeepTheirTextWithoutInventingMetadata() {
    for title in ["Research", "Research — 4 tabs", "Gruppe Recherche - 4 Tabs", "group Something unexpected"] {
        let caption = TabGroupCaption(title)
        #expect(caption.title == title)
        #expect(caption.detail == "Tab group")
    }
    #expect(TabGroupCaption(" ").title == "Tab group")
}
