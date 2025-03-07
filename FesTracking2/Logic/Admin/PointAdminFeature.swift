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
            case let .setPoint(point):
                state.point = point
                return .none
            case let .setTitle(title):
                state.point.title = title
                return .none
            case let .setDescription(description):
                state.point.description = description
                return .none
            case let .setTime(time):
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
