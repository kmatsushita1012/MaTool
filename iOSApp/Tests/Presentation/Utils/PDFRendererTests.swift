import Testing
import CoreGraphics
import UIKit
import Shared
@testable import iOSApp


struct PDFRendererTests {
    @Test func PDFファイル名はgroupがあると先頭に付く() {
        let district = District(id: "district-1", name: "中央町", festivalId: "festival-1", group: "1組")

        #expect(district.pdfFileName() == "(1組) 中央町.pdf")
        #expect(district.pdfFileName(suffix: "_行動表") == "(1組) 中央町_行動表.pdf")
    }

    @Test func PDFファイル名はgroupがnilなら町名のみを使う() {
        let district = District(id: "district-1", name: "中央町", festivalId: "festival-1", group: nil)

        #expect(district.pdfFileName() == "中央町.pdf")
    }

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

    @Test func 行動表文字は最小フォントでも収まらない場合に折り返す() {
        let layout = ActionTableTextFitter.layout(
            for: "とても長いRoutePassageの説明テキスト",
            maxFontSize: 15,
            minFontSize: 9,
            width: 40,
            height: 24
        )

        #expect(layout.fontSize == 9)
        #expect(layout.shouldWrap)
    }

    @Test @MainActor func 行動表は自町の通過町を自町と表示する() {
        let district = District(id: "district-1", name: "中央町", festivalId: "festival-1")
        let route = Route(id: "route-1", districtId: district.id, periodId: "period-1")
        let passage = RoutePassage(routeId: route.id, districtId: district.id, memo: "中央町を通過")

        let title = ActionTableSnapshotter.passageTitle(passage, routeDistrictId: route.districtId)
        #expect(title == "自町")
    }

    @Test func ルート地図キャプションは赤丸矩形を避ける() {
        let planner = RouteMapCaptionLayoutPlanner()
        let input = RouteMapCaptionLayoutPlanner.CaptionInput(
            text: "1",
            anchor: CGPoint(x: 20, y: 20),
            textSize: CGSize(width: 10, height: 10),
            padding: 2,
            margin: 5
        )
        let pinRect = CGRect(x: 25, y: 1, width: 14, height: 14)

        let placements = planner.placeCaptions(inputs: [input], occupiedRects: [pinRect])

        #expect(placements.count == 1)
        #expect(!placements[0].rect.intersects(pinRect))
        #expect(placements[0].rect.origin.y > 20)
    }

    @Test func ルート地図キャプションは後続が詰む場合に前の候補を戻して再探索する() {
        let planner = RouteMapCaptionLayoutPlanner()
        let inputs = [
            RouteMapCaptionLayoutPlanner.CaptionInput(
                text: "A",
                anchor: CGPoint(x: 20, y: 20),
                textSize: CGSize(width: 10, height: 10),
                padding: 2,
                margin: 5
            ),
            RouteMapCaptionLayoutPlanner.CaptionInput(
                text: "B",
                anchor: CGPoint(x: 44, y: 20),
                textSize: CGSize(width: 10, height: 10),
                padding: 2,
                margin: 5
            )
        ]
        let occupiedRects = [
            CGRect(x: 49, y: 1, width: 14, height: 14),
            CGRect(x: 49, y: 25, width: 14, height: 14),
            CGRect(x: 25, y: 25, width: 14, height: 14)
        ]

        let placements = planner.placeCaptions(inputs: inputs, occupiedRects: occupiedRects)

        #expect(placements.count == 2)
        #expect(placements[0].rect.origin.x < 20)
        #expect(placements[1].rect.origin.x == 25)
        #expect(placements[1].rect.origin.y == 1)
    }

    @Test func ルート地図キャプションは完全解がない場合に最も長い無衝突プレフィックスを持つ組み合わせを返す() {
        let planner = RouteMapCaptionLayoutPlanner()
        let inputs = [
            RouteMapCaptionLayoutPlanner.CaptionInput(
                text: "A",
                anchor: CGPoint(x: 20, y: 20),
                textSize: CGSize(width: 10, height: 10),
                padding: 2,
                margin: 5
            ),
            RouteMapCaptionLayoutPlanner.CaptionInput(
                text: "B",
                anchor: CGPoint(x: 68, y: 20),
                textSize: CGSize(width: 10, height: 10),
                padding: 2,
                margin: 5
            )
        ]
        let occupiedRects = [
            CGRect(x: 49, y: 1, width: 1, height: 1),
            CGRect(x: 49, y: 25, width: 14, height: 14),
            CGRect(x: 25, y: 25, width: 14, height: 14),
            CGRect(x: 73, y: 1, width: 14, height: 14),
            CGRect(x: 73, y: 25, width: 14, height: 14)
        ]

        let placements = planner.placeCaptions(inputs: inputs, occupiedRects: occupiedRects)

        #expect(placements.count == 2)
        #expect(placements[0].text == "A")
        #expect(!placements[0].rect.intersects(occupiedRects[0]))
        #expect(placements[1].text == "B")
        #expect(placements[1].rect.origin == CGPoint(x: 49, y: 1))
    }

    @Test func ルート地図キャプションは全方向が塞がると面積が小さい候補で返す() {
        let planner = RouteMapCaptionLayoutPlanner()
        let input = RouteMapCaptionLayoutPlanner.CaptionInput(
            text: "1",
            anchor: CGPoint(x: 20, y: 20),
            textSize: CGSize(width: 10, height: 10),
            padding: 2,
            margin: 5
        )
        let occupiedRects = [
            CGRect(x: 26, y: 2, width: 1, height: 1),
            CGRect(x: 25, y: 25, width: 14, height: 14),
            CGRect(x: 1, y: 25, width: 14, height: 14),
            CGRect(x: 1, y: 1, width: 14, height: 14)
        ]

        let placements = planner.placeCaptions(inputs: [input], occupiedRects: occupiedRects)

        #expect(placements.count == 1)
        #expect(placements[0].rect.origin == CGPoint(x: 25, y: 1))
    }
}
