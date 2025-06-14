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
    @Bindable var store: StoreOf<AdminRouteExport>
    
    @State private var partialSnapshot: UIImage? = nil
    @State private var wholeSnapshot: UIImage? = nil
    
    var body: some View{
        // 背景のMap
        NavigationStack{
            ZStack {
                ExportableMap(
                    points: store.points,
                    segments: store.segments,
                    region: $store.region,
                    wholeSnapshot: $wholeSnapshot,
                    partialSnapshot: $partialSnapshot
                )
                    .ignoresSafeArea(edges: .bottom)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        store.send(.dismissTapped)
                    }) {
                        Image(systemName: "chevron.left")
                        Text("戻る")
                    }
                    .padding(.horizontal, 8)
                }
                ToolbarItem(placement: .principal) {
                    Text(store.title)
                        .bold()
                }
                if let partialSnapshot = partialSnapshot,
                   let partialPdf = createPDF(with: partialSnapshot, path: store.partialPath){
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(
                            item: partialPdf,
                            preview: SharePreview(
                                "行動図",
                                image: Image(systemName: "camera")
                            )
                        ){
                            Image(systemName: "camera")
                        }
                    }
                }
                if let wholeSnapshot = wholeSnapshot,
                   let wholePdf = createPDF(with: wholeSnapshot, path: store.wholePath){
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(
                           item: wholePdf,
                           preview: SharePreview(
                                "行動図（全体）",
                                image: Image(systemName: "point.topright.arrow.triangle.backward.to.point.bottomleft.scurvepath")
                           )
                        ){
                            Image(systemName: "point.topright.arrow.triangle.backward.to.point.bottomleft.scurvepath")
                        }
                    }
                }
                
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func createPDF(with image: UIImage,path: String) -> URL? {
       let pdfData = NSMutableData()
       let pdfRect = CGRect(origin: .zero, size: image.size)
       UIGraphicsBeginPDFContextToData(pdfData, pdfRect, nil)
       UIGraphicsBeginPDFPage()
       image.draw(in: pdfRect)
       UIGraphicsEndPDFContext()

       let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(path)
       do {
           try pdfData.write(to: tempURL, options: .atomic)
           return tempURL
       } catch {
           return nil
       }
    }
}

