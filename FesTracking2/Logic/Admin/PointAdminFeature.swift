//
//  PointAdmin.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/06.
//

import ComposableArchitecture

struct PointAdminState: Equatable{
    var point: Point
}

enum PointAdminAction{
    case setPoint(Point)
    case setTitle(String?)
    case setDescription(String?)
    case setTime(Time)
    case eraseTime
    case save
}

struct PointAdminFeature: Reducer{
    var body: some Reducer<PointAdminState, PointAdminAction> {
        Reduce { state, action in
            switch action{
            case .setPoint(let point):
                state.point = point
                return .none
            case .setTitle(let title):
                state.point.title = title
                return .none
            case .setDescription(let description):
                state.point.description = description
                return .none
            case .setTime(let time):
                state.point.time = time
                return .none
            case .eraseTime:
                state.point.time = nil
                return .none
            case .save:
                //TODO
                return .none
            }
        }
    }
}
