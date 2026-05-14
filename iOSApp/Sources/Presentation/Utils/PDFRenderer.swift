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
        let fieldCount: Int
    }

    private let district: District
    private let slots: [RouteSlot]

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

            let tableTop: CGFloat = 132
            let tableBottom: CGFloat = 792
            let tableLeft: CGFloat = 36
            let tableRight: CGFloat = pageSize.width - 36

            drawHeader(in: context.cgContext, size: pageSize, date: date)

            let rows = makeRows(from: daySlots)
            let rowCount = max(rows.count, 1)
            let maxFieldCount = max(rows.map(\.fieldCount).max() ?? 4, 4)
            let contentColumnCount = max(maxFieldCount * 2 - 1, 1)
            let tableRect = CGRect(
                x: tableLeft,
                y: tableTop,
                width: tableRight - tableLeft,
                height: tableBottom - tableTop
            )
            drawTable(
                in: context.cgContext,
                tableRect: tableRect,
                rowCount: rowCount,
                contentColumnCount: contentColumnCount,
                rows: rows
            )
        }
    }

    private func drawHeader(in ctx: CGContext, size: CGSize, date: SimpleDate) {
        let dateText = "\(date.day)日"
        let districtText = "町名（\(district.name)区）"
        let titleText = "行動表"

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 28, weight: .bold),
            .foregroundColor: UIColor.black
        ]
        let titleSize = titleText.size(withAttributes: titleAttributes)
        titleText.draw(
            at: CGPoint(x: (size.width - titleSize.width) / 2, y: 20),
            withAttributes: titleAttributes
        )

        let textAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 20, weight: .bold),
            .foregroundColor: UIColor.black
        ]
        dateText.draw(at: CGPoint(x: 36, y: 78), withAttributes: textAttr)

        let districtSize = districtText.size(withAttributes: textAttr)
        districtText.draw(
            at: CGPoint(x: size.width - districtSize.width - 36, y: 78),
            withAttributes: textAttr
        )

        ctx.setStrokeColor(UIColor.black.cgColor)
        ctx.setLineWidth(1)
        ctx.move(to: CGPoint(x: 36, y: 116))
        ctx.addLine(to: CGPoint(x: size.width - 36, y: 116))
        ctx.strokePath()
    }

    private func drawTable(
        in ctx: CGContext,
        tableRect: CGRect,
        rowCount: Int,
        contentColumnCount: Int,
        rows: [Row]
    ) {
        let leftColumnWidth: CGFloat = 64
        let bodyWidth = tableRect.width - leftColumnWidth
        let contentWidth = bodyWidth / CGFloat(max(contentColumnCount, 1))
        let rowHeight = tableRect.height / CGFloat(max(rowCount, 1))

        ctx.setStrokeColor(UIColor.black.cgColor)
        ctx.setLineWidth(1.2)
        ctx.stroke(tableRect)

        let splitX = tableRect.minX + leftColumnWidth
        ctx.move(to: CGPoint(x: splitX, y: tableRect.minY))
        ctx.addLine(to: CGPoint(x: splitX, y: tableRect.maxY))

        for column in 1..<contentColumnCount {
            let x = splitX + CGFloat(column) * contentWidth
            ctx.move(to: CGPoint(x: x, y: tableRect.minY))
            ctx.addLine(to: CGPoint(x: x, y: tableRect.maxY))
        }

        for row in 1..<rowCount {
            let y = tableRect.minY + CGFloat(row) * rowHeight
            ctx.move(to: CGPoint(x: tableRect.minX, y: y))
            ctx.addLine(to: CGPoint(x: tableRect.maxX, y: y))
        }
        ctx.strokePath()

        for rowIndex in 0..<rowCount {
            guard rowIndex < rows.count else { continue }
            let row = rows[rowIndex]
            let y = tableRect.minY + CGFloat(rowIndex) * rowHeight
            drawVerticalText(
                row.period.title,
                in: CGRect(x: tableRect.minX, y: y, width: leftColumnWidth, height: rowHeight)
            )
            for columnIndex in 0..<contentColumnCount {
                let rect = CGRect(
                    x: splitX + CGFloat(columnIndex) * contentWidth,
                    y: y,
                    width: contentWidth,
                    height: rowHeight
                )
                if columnIndex % 2 == 1 {
                    drawCenteredText("→", in: rect, fontSize: 16)
                }
            }
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
            y: rect.midY - (fontSize + 6) / 2,
            width: rect.width - 8,
            height: fontSize + 8
        )
        (text as NSString).draw(in: drawRect, withAttributes: attrs)
    }

    private func drawVerticalText(_ text: String, in rect: CGRect) {
        let chars = text.map { String($0) }
        guard !chars.isEmpty else { return }
        let fontSize: CGFloat = 15
        let totalHeight = CGFloat(chars.count) * (fontSize + 2)
        var currentY = rect.midY - totalHeight / 2
        for char in chars {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize, weight: .semibold),
                .foregroundColor: UIColor.black
            ]
            let size = char.size(withAttributes: attrs)
            let x = rect.midX - size.width / 2
            char.draw(at: CGPoint(x: x, y: currentY), withAttributes: attrs)
            currentY += fontSize + 2
        }
    }

    private func makeRows(from daySlots: [RouteSlot]) -> [Row] {
        daySlots.map { slot in
            let fieldCount: Int
            if let route = slot.route {
                let passages: [RoutePassage] = FetchAll(routeId: route.id).wrappedValue.sorted { $0.order < $1.order }
                fieldCount = max(passages.count, 4)
            } else {
                fieldCount = 4
            }
            return Row(period: slot.period, fieldCount: fieldCount)
        }
    }
}
