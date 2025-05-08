//
//  AdminRouteExportFeature.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/08.
//

import ComposableArchitecture
import MapKit

@Reducer
struct AdminRouteExportFeature {
    @ObservableState
    struct State: Equatable {
        let route: Route
        var points: [Point] {
            route.points.filter{ $0.title != nil }
        }
        var segments: [Segment] {
            route.segments
        }
        var path:String {
            route.title
        }
        init(route:Route){
            self.route = route
        }
    }
    @CasePathable
    enum Action: Equatable,BindableAction {
        case binding(BindingAction<State>)
        case exportTapped
        case homeTapped
    }
    
    var body: some ReducerOf<AdminRouteExportFeature> {
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .binding(_):
                return .none
            case .exportTapped:
                return .none
            case .homeTapped:
                return .none
            }
        }
    }
}



func fileSave(fileName: String) -> URL {
    let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    let filePath = dir.appendingPathComponent(fileName, isDirectory: false)
    return filePath
}
