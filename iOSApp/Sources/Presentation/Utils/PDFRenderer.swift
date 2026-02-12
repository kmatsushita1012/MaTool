//
//  PDFRenderer.swift
//  MaTool
//
//  Created by 松下和也 on 2026/01/29.
//

@preconcurrency import PDFKit

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
