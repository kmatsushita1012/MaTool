//
//  LiveRepository.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/02.
//

import Foundation
import Dependencies

extension ApiClient: DependencyKey {
    static let liveValue = Self.noop
    static let live = Self(
        getRegionSummaries: {
            let response = await performGetRequest(
                path: "/region/summaries"
            )
            return decodeResponse([RegionSummary].self, from: response)
        },
        getRegionDetail: { id in
            let response = await performGetRequest(
                path: "/region/detail",
                query: ["id":id]
            )
            return decodeResponse(Region.self, from: response)
        },
        getDistrictSummaries: { regionId in
            let response = await performGetRequest(
                path: "/district/summaries",
                query: ["regionId":regionId]
            )
            return decodeResponse([DistrictSummary].self, from: response)
        },
        getDistrictDetail: { id in
            let response = await performGetRequest(
                path: "/district/detail",
                query: ["id":id]
            )
            return decodeResponse(District.self, from: response)
        },
        getRouteSummaries: { districtId in
            let response = await performGetRequest(
                path: "/route/summaries",
                query: ["districtId":districtId]
            )
            return decodeResponse([RouteSummary].self, from: response)
        },
        getRouteDetail: { districtId, date, title in
            var query:[String:Any];
            if let date = date,
               let title = title{
                query = [
                    "districtId":districtId,
                    "year":date.year,
                    "month":date.month,
                    "day":date.day,
                    "title":title
                ]
            }else{
                query = [
                    "districtId":districtId,
                ]
            }
            let response = await performGetRequest(
                path: "/route/detail",
                query: query
            )
            return decodeResponse(Route.self, from: response)
        },
        getLocation: { districtId in
            let response = await performGetRequest(
                path: "/location",
                query: ["id" : districtId ]
            )
            return decodeResponse(Location?.self, from: response)
        },
        postRegion: { region, accessToken in
            let body = encodeRequest(region)
            switch body {
            case .success(let body):
                
                let response = await performPostRequest(path: "/region", body: body,accessToken: accessToken)
                return decodeResponse(String.self, from: response)
            case .failure(let failure):
                return Result.failure(ApiError.encoding(failure.localizedDescription))
            }
        },
        postDistrict: { district, accessToken in
            let body = encodeRequest(district)
            switch body {
            case .success(let body):
                let response = await performPostRequest(path: "/district", body: body,accessToken: accessToken)
                return decodeResponse(String.self, from: response)
            case .failure(let failure):
                return Result.failure(ApiError.encoding(failure.localizedDescription))
            }
        },
        postRoute: { route, accessToken in
            let body = encodeRequest(route)
            switch body {
            case .success(let body):
                let response = await performPostRequest(path: "/route", body: body,accessToken: accessToken)
                return decodeResponse(String.self, from: response)
            case .failure(let failure):
                return Result.failure(ApiError.encoding(failure.localizedDescription))
            }
        },
        deleteRoute: { districtId, date, title, accessToken in
            let response = await performDeleteRequest(
                path: "/route",
                query: [
                    "districtId":districtId,
                    "year":String(date.year),
                    "month":String(date.month),
                    "day":String(date.day),
                    "title":title
                ]
                
            )
            return decodeResponse(String.self, from: response)
        },
        postLocation: { location,accessToken in
            let body = encodeRequest(location)
            switch body {
            case .success(let body):
                let response = await performPostRequest(path: "/location", body: body,accessToken: accessToken)
                return decodeResponse(String.self, from: response)
            case .failure(let failure):
                return Result.failure(ApiError.encoding(failure.localizedDescription))
            }
        },
        deleteLocation: { id, accessToken in
            let response = await performDeleteRequest(
                path: "/location",
                query: ["districtId":id]
            )
            return decodeResponse(String.self, from: response)
        },
        getSegmentCoordinate: { coordinate1, coordinate2 in
            let response = await performGetRequest(
                path: "/route/detail",
                query: [
                    "lat1": coordinate1.latitude,
                    "lon1": coordinate1.longitude,
                    "lat2": coordinate2.latitude,
                    "lon2": coordinate2.longitude
                ]
            )
            return decodeResponse([Coordinate].self, from: response)
        }
    )
    static private func decodeResponse<T:Codable>(_ type:T.Type, from response: Result<Data,Error>)->Result<T,ApiError>{
        switch response {
        case .success(let data):
            do{
                let decodedObject = try JSONDecoder().decode(type, from: data)
                return Result.success(decodedObject)
            }catch{
                //TODO
                return Result.failure(ApiError.decoding("レスポンスの解析に失敗しました"))
            }
        case .failure(let error):
            return Result.failure(ApiError.network(error.localizedDescription))
        }
    }
    static private func encodeRequest<T: Encodable>(_ object: T) -> Result<Data, Error> {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted // オプション: JSONを見やすくする
        do {
            let data = try encoder.encode(object)
            return .success(data)
        } catch {
            return .failure(error)
        }
    }
}
