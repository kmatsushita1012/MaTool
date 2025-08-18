//
//  AdminRouteExport.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/08.
//

import ComposableArchitecture
import MapKit
import Foundation

@Reducer
struct AdminRouteExport {
    
    @ObservableState
    struct State: Equatable {
        let route: RouteInfo
        let snapshotter: RouteSnapshotter
        
        var region: MKCoordinateRegion?
        var mapViewSize: CGSize?
        
        var partialImage: UIImage?
        var wholeImage: UIImage?
        
        var partialPDF: URL? {
            guard let partialImage else { return nil }
            return createPDF(with: partialImage, path: "\(route.text(format: "D_y-m-d_T"))_part_\(Date().stamp).pdf")
        }
        var wholePDF: URL? {
            guard let wholeImage else { return nil }
            return createPDF(with: wholeImage, path: "\(route.text(format: "D_y-m-d_T"))_full.pdf")
        }
        
        var isPartialPresented: Bool = false
        var isWholePresented: Bool = false
        
        var points: [Point] {
            PointFilter.export.apply(to: route)
        }
        var segments: [Segment] {
            route.segments
        }
        var title: String {
            route.text(format: "m/d T")
        }
        
        init(route: RouteInfo){
            self.route = route
            region = makeRegion(route.points.map{ $0.coordinate })
            snapshotter = RouteSnapshotter(route)
        }
    }
    
    @CasePathable
    enum Action: Equatable, BindableAction {
        case onAppear
        case binding(BindingAction<State>)
        case partialTapped
        case wholeTapped
        case partialImagePrepared(UIImage?)
        case wholeImagePrepared(UIImage?)
        case dismissTapped
    }
    
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<AdminRouteExport> {
        BindingReducer()
        Reduce{ state, action in
            print("\(action)")
            switch action {
            case .onAppear:
                return .run {[snapshotter = state.snapshotter] send in
                    let image = try! await snapshotter.take()
                    await send(.wholeImagePrepared(image))
                }
            case .binding:
                return .none
            case .partialTapped:
                return .run {[
                    snapshotter = state.snapshotter,
                    region = state.region,
                    size = state.mapViewSize
                ] send in
                    guard let region, let size else { return }
                    let image = try! await snapshotter.take(of: region, size: size)
                    await send(.partialImagePrepared(image))
                }
            case .wholeTapped:
                state.isWholePresented = true
                return .none
            case .partialImagePrepared(let image):
                state.partialImage = image
                state.isPartialPresented = true
                return .none
            case .wholeImagePrepared(let image):
                state.wholeImage = image
                return .none
            case .dismissTapped:
                return .run{ _ in
                    await dismiss()
                }
            }
        }
    }
}


extension AdminRouteExport.State {
   
    
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
