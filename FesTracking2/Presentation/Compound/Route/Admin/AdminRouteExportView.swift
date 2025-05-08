//
//  AdminRouteExportView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/08.
//

import SwiftUI
import ComposableArchitecture
import MapKit
import UniformTypeIdentifiers

struct AdminRouteExportView: View{
    @Bindable var store: StoreOf<AdminRouteExportFeature>
    
    @State private var pdfItem: PDFItem? = nil
    @State private var showPDFShare = false
    
    // renderメソッドは、shareViewを画像としてレンダリングします。
    // ここでは使いませんが.cgImageも選択可能です
    func renderPDF() {
        DispatchQueue.main.async {
            let renderer = ImageRenderer(content: mapView)
            print(renderer)
            print(renderer.uiImage)
            if let uiImage = renderer.uiImage {
                let bounds = CGRect(origin: .zero, size: uiImage.size)
                let format = UIGraphicsPDFRendererFormat()
                let pdfRenderer = UIGraphicsPDFRenderer(bounds: bounds, format: format)

                let data = pdfRenderer.pdfData { context in
                    context.beginPage()
                    uiImage.draw(in: bounds)
                }

                // 一時ファイルに保存
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("route_\(UUID().uuidString).pdf")

                do {
                    try data.write(to: tempURL)
                    self.pdfItem = PDFItem(url: tempURL)
                } catch {
                    print("PDFの保存に失敗: \(error)")
                }
            } else {
                print("画像のレンダリングに失敗")
            }
        }
    }

    
    var mapView: some View {
        RouteAdminMap(
            points: store.points,
            segments: store.segments,
        )
        .background(.white)
    }
    
    var body: some View{
        // 背景のMap
        NavigationStack{
            ZStack {
                mapView
            }
            .onAppear(){
                print("render")
                renderPDF()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        store.send(.homeTapped)
                    }) {
                        Image(systemName: "house")
                    }
                    .padding(.horizontal, 8)
                }
                ToolbarItem(placement: .principal) {
                    Text("ルート編集")
                        .bold()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if let pdfItem {
                        ShareLink(
                            item: pdfItem,
                            subject: Text("ルートを共有"),
                            preview: SharePreview(
                                "アイテム",
                                image: Image(systemName: "doc.richtext")
                            )
                        )
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        
    }
}

struct PDFItem: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        // PDFファイルを転送するための設定
        FileRepresentation(
            contentType: .pdf,
            exporting: { item in
                SentTransferredFile(item.url)
            },
            importing: { (importedFile: ReceivedTransferredFile) async throws -> PDFItem in
                return PDFItem(url: importedFile.file)
           }
        )
    }
}

