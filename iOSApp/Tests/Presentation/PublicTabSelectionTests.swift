import Testing
@testable import iOSApp

struct PublicTabSelectionTests {
    @Test("連動時は地図と紹介が同じ選択コンテキストを参照する")
    func linkedSelectionUsesOneContext() {
        let context = PublicSelectionContext(
            festivalID: "festival-1",
            districtID: "district-1",
            routeID: "route-1"
        )

        let selection = PublicTabSelection.initial(linked: true, context: context)

        #expect(selection.isLinked)
        #expect(selection.context(for: .map) == context)
        #expect(selection.context(for: .info) == context)
    }

    @Test("非連動時は地図と紹介の選択を個別に保持する")
    func unlinkedSelectionKeepsTabContexts() {
        let initial = PublicTabSelection.initial(
            linked: false,
            context: PublicSelectionContext(festivalID: "festival-1")
        )
        let infoContext = PublicSelectionContext(
            festivalID: "festival-2",
            districtID: "district-2"
        )

        let selection = initial.updating(infoContext, from: .info)

        #expect(!selection.isLinked)
        #expect(
            selection.context(for: .map)
                == PublicSelectionContext(festivalID: "festival-1")
        )
        #expect(selection.context(for: .info) == infoContext)
    }

    @Test("連動を有効にした時は地図側の選択を共有する")
    func enablingLinkingUsesMapContext() {
        let mapContext = PublicSelectionContext(
            festivalID: "festival-1",
            districtID: "district-1"
        )
        let infoContext = PublicSelectionContext(festivalID: "festival-2")
        let selection = PublicTabSelection.initial(linked: false, context: mapContext)

        let linked = selection.settingLinking(
            true,
            mapContext: mapContext,
            infoContext: infoContext
        )

        #expect(linked.isLinked)
        #expect(linked.context(for: .map) == mapContext)
        #expect(linked.context(for: .info) == mapContext)
    }
}
