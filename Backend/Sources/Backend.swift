//
//  Backend.swift
//  MaTool
//
//  Created by 松下和也 on 2025/11/14.
//


@main
struct MaToolAPI: APIGateway {
    static let app = Application{
        AuthMiddleware(path: "/")
        PeriodRouter()
        FestivalRouter()
        DistrictRouter()
        RouteRouter()
    }
}

//差分注入
