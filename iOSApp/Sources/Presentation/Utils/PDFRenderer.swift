//
//  PDFRenderer.swift
//  MaTool
//
//  Created by 松下和也 on 2026/01/29.
//

@preconcurrency import PDFKit
import UIKit
import Shared
import SQLiteData

@MainActor
final class PDFRenderer: Sendable {
    private let pdfDocument = PDFDocument()
    private let path: String
    private var pageIndex = 0
    
    init(path: String) {
        self.path = path
    }
    
    func addPage(with image: UIImage) {
        let page = PDFPage(image: image)
        pdfDocument.insert(page!, at: pageIndex)
        pageIndex += 1
    }
    
    func finalize() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(path)
        pdfDocument.write(to: url)
        return url
    }
}

@MainActor
struct ActionTableSnapshotter: Sendable {
    private struct Row: Sendable {
        let period: Period
        let entries: [String]
    }

    private let district: District
    private let slots: [RouteSlot]
    private let linesPerPeriod = 5
    private let columnsPerLine = 5
    private let pageLift: CGFloat = -24
    private let titleFontSize: CGFloat = 31
    private let subtitleFontSize: CGFloat = 22
    private let rowFontSize: CGFloat = 15
    private let arrowFontSize: CGFloat = 16

    init(district: District, slots: [RouteSlot]) {
        self.district = district
        self.slots = slots
    }

    func takeAll() -> [UIImage] {
        let grouped = Dictionary(grouping: slots) { $0.period.date }
        return grouped.keys.sorted().compactMap { date in
            let daySlots = (grouped[date] ?? []).sorted { lhs, rhs in
                lhs.period < rhs.period
            }
            return drawPage(date: date, daySlots: daySlots)
        }
    }

    private func drawPage(date: SimpleDate, daySlots: [RouteSlot]) -> UIImage {
        let pageSize = CGSize(width: 595, height: 842) // A4 portrait 72dpi
        let renderer = UIGraphicsImageRenderer(size: pageSize)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: pageSize))

            // 見本画像に合わせてヘッダ余白を大きく確保
            let tableTop: CGFloat = 320 + pageLift
            let tableBottom: CGFloat = 760 + pageLift
            let tableLeft: CGFloat = 42
            let tableRight: CGFloat = pageSize.width - 42

            drawHeader(in: context.cgContext, size: pageSize, date: date)

            let rows = makeRows(from: daySlots)
            let tableRect = CGRect(
                x: tableLeft,
                y: tableTop,
                width: tableRight - tableLeft,
                height: tableBottom - tableTop
            )
            drawTable(
                in: context.cgContext,
                tableRect: tableRect,
                rows: rows
            )
        }
    }

    private func drawHeader(in ctx: CGContext, size: CGSize, date: SimpleDate) {
        let dateText = "\(date.day)日"
        let districtText = "町名（\(district.name)区）"
        let titleText = "行動表"

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: titleFontSize, weight: .bold),
            .foregroundColor: UIColor.black
        ]
        let titleSize = titleText.size(withAttributes: titleAttributes)
        titleText.draw(
            at: CGPoint(x: (size.width - titleSize.width) / 2, y: 196 + pageLift),
            withAttributes: titleAttributes
        )

        let textAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: subtitleFontSize, weight: .bold),
            .foregroundColor: UIColor.black
        ]
        dateText.draw(at: CGPoint(x: 42, y: 278 + pageLift), withAttributes: textAttr)

        let districtSize = districtText.size(withAttributes: textAttr)
        districtText.draw(
            at: CGPoint(x: size.width - districtSize.width - 42, y: 278 + pageLift),
            withAttributes: textAttr
        )
    }

    private func drawTable(
        in ctx: CGContext,
        tableRect: CGRect,
        rows: [Row]
    ) {
        let leftColumnWidth: CGFloat = 62
        let totalLineCount = max(rows.count * linesPerPeriod, 1)
        let lineHeight = tableRect.height / CGFloat(totalLineCount)
        let bodyLeft = tableRect.minX + leftColumnWidth
        let bodyWidth = tableRect.width - leftColumnWidth

        ctx.setStrokeColor(UIColor.black.cgColor)
        ctx.setLineWidth(1.2)
        ctx.stroke(tableRect)

        // 見出し(左列)の区切り縦線は残す
        ctx.move(to: CGPoint(x: bodyLeft, y: tableRect.minY))
        ctx.addLine(to: CGPoint(x: bodyLeft, y: tableRect.maxY))
        ctx.strokePath()

        var currentY = tableRect.minY
        for row in rows {
            let rowLineCount = linesPerPeriod
            let rowHeight = CGFloat(rowLineCount) * lineHeight
            drawVerticalText(
                row.period.title,
                in: CGRect(x: tableRect.minX, y: currentY, width: leftColumnWidth, height: rowHeight)
            )
            for line in 0..<rowLineCount {
                let baseIndex = line * columnsPerLine
                let rect = CGRect(
                    x: bodyLeft,
                    y: currentY + CGFloat(line) * lineHeight,
                    width: bodyWidth,
                    height: lineHeight
                )
                drawArrowGuides(in: rect)
                drawEntryTexts(
                    row.entries,
                    baseIndex: baseIndex,
                    in: rect
                )
            }

            // 横線は各日程(時間帯)の境界線のみ
            let separatorY = currentY + rowHeight
            if separatorY < tableRect.maxY - 0.5 {
                ctx.move(to: CGPoint(x: tableRect.minX, y: separatorY))
                ctx.addLine(to: CGPoint(x: tableRect.maxX, y: separatorY))
                ctx.strokePath()
            }
            currentY += rowHeight
        }
    }

    private func drawEntryTexts(_ entries: [String], baseIndex: Int, in rect: CGRect) {
        let columnWidth = rect.width / CGFloat(columnsPerLine)
        for column in 0..<columnsPerLine {
            let entryIndex = baseIndex + column
            guard entryIndex < entries.count else { continue }
            let cellRect = CGRect(
                x: rect.minX + CGFloat(column) * columnWidth,
                y: rect.minY,
                width: columnWidth,
                height: rect.height
            )
            drawCenteredText(entries[entryIndex], in: cellRect, fontSize: rowFontSize)
        }
    }

    private func drawArrowGuides(in rect: CGRect) {
        // 5列の入力欄を想定し、矢印は列間(4箇所)に整列表示
        let gapCount = max(columnsPerLine - 1, 1)
        let bodyWidth = rect.width - 24
        for index in 0..<gapCount {
            let x = rect.minX + 12 + bodyWidth * CGFloat(index + 1) / CGFloat(columnsPerLine)
            drawCenteredText(
                "→",
                in: CGRect(x: x - 10, y: rect.minY, width: 20, height: rect.height),
                fontSize: arrowFontSize
            )
        }
    }

    private func drawCenteredText(_ text: String, in rect: CGRect, fontSize: CGFloat) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byTruncatingTail
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .medium),
            .foregroundColor: UIColor.black,
            .paragraphStyle: paragraph
        ]
        let drawRect = CGRect(
            x: rect.minX + 4,
            y: rect.midY - (fontSize + 8) / 2,
            width: rect.width - 8,
            height: fontSize + 10
        )
        (text as NSString).draw(in: drawRect, withAttributes: attrs)
    }

    private func drawVerticalText(_ text: String, in rect: CGRect) {
        let chars = text.map { String($0) }
        guard !chars.isEmpty else { return }
        let fontSize: CGFloat = 17
        let totalHeight = CGFloat(chars.count) * (fontSize + 3)
        var currentY = rect.midY - totalHeight / 2
        for char in chars {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize, weight: .semibold),
                .foregroundColor: UIColor.black
            ]
            let size = char.size(withAttributes: attrs)
            let x = rect.midX - size.width / 2
            char.draw(at: CGPoint(x: x, y: currentY), withAttributes: attrs)
            currentY += fontSize + 3
        }
    }

    private func makeRows(from daySlots: [RouteSlot]) -> [Row] {
        daySlots.map { slot in
            let entries: [String] = {
                guard let route = slot.route else { return [] }
                let passages:[RoutePassage] = FetchAll(routeId: route.id).wrappedValue
                return passages.prefix(linesPerPeriod * columnsPerLine).map(passageTitle)
            }()
            return Row(
                period: slot.period,
                entries: entries
            )
        }
    }

    private func passageTitle(_ passage: RoutePassage) -> String {
        if let districtId = passage.districtId,
           let district = FetchOne(District.find(districtId)).wrappedValue {
            return district.name
        }

        if let memo = passage.memo?.trimmingCharacters(in: .whitespacesAndNewlines),
           !memo.isEmpty {
            return memo
        }

        return "(未設定)"
    }
}
