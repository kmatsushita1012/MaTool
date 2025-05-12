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
    
    @State private var mapSnapshot: UIImage? = nil
    
    var body: some View{
        // 背景のMap
        NavigationStack{
            ZStack {
                ExportableMap(
                    points: store.points,
                    segments: store.segments,
                    mapSnapshot: $mapSnapshot,
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
                    Text("ルート出力")
                        .bold()
                }
                if let image = mapSnapshot,
                    let pdf = createPDF(with: image){
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(
                           item: pdf,
                           preview: SharePreview(
                                        "行動図",
                                        image: Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")))
                    }
                    
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        
    }
}

func createPDF(with image: UIImage) -> URL? {
   let pdfData = NSMutableData()
   let pdfRect = CGRect(origin: .zero, size: image.size)
   UIGraphicsBeginPDFContextToData(pdfData, pdfRect, nil)
   UIGraphicsBeginPDFPage()
   image.draw(in: pdfRect)
   UIGraphicsEndPDFContext()

   let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("map.pdf")
   do {
       try pdfData.write(to: tempURL, options: .atomic)
       return tempURL
   } catch {
       return nil
   }
}

struct PDFItem: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: \.url)
    }
}

