import Testing
import CoreGraphics
import Shared
@testable import iOSApp


struct PDFRendererTests {
    @Test func 行動表レイアウトは矢印用の余白を確保する() {
        let rect = CGRect(x: 0, y: 0, width: 250, height: 24)
        let layout = ActionTableLineLayout(rect: rect, columns: 5, arrowWidth: 20)

        #expect(layout.textRects.count == 5)
        #expect(layout.arrowRects.count == 4)

        for index in 0..<layout.arrowRects.count {
            #expect(layout.textRects[index].maxX <= layout.arrowRects[index].minX)
            #expect(layout.arrowRects[index].maxX <= layout.textRects[index + 1].minX)
        }
    }

    @Test func 行動表文字は長文時のみ縮小する() {
        let shortFontSize = ActionTableTextFitter.fontSize(
            for: "中央町",
            maxFontSize: 15,
            minFontSize: 9,
            width: 80
        )
        let longFontSize = ActionTableTextFitter.fontSize(
            for: "とても長いRoutePassageの説明テキスト",
            maxFontSize: 15,
            minFontSize: 9,
            width: 80
        )

        #expect(shortFontSize == 15)
        #expect(longFontSize < shortFontSize)
        #expect(longFontSize >= 9)
    }

    @Test @MainActor func 行動表は自町の通過町を自町と表示する() {
        let district = District(id: "district-1", name: "中央町", festivalId: "festival-1")
        let route = Route(id: "route-1", districtId: district.id, periodId: "period-1")
        let passage = RoutePassage(routeId: route.id, districtId: district.id, memo: "中央町を通過")

        let title = ActionTableSnapshotter.passageTitle(passage, routeDistrictId: route.districtId)
        #expect(title == "自町")
    }
}
