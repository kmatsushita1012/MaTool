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
        getRegions: {
            let response = await performGetRequest(
                path: "/regions"
            )
            return decodeResponse([Region].self, from: response)
        },
        getRegion: { id in
            let response = await performGetRequest(
                path: "/regions/\(id)"
            )
            return decodeResponse(Region.self, from: response)
        },
        putRegion: { region, accessToken in
            let body = encodeRequest(region)
            switch body {
            case .success(let body):
                let response = await performPutRequest(path: "/region/\(region.id)", body: body,accessToken: accessToken)
                return decodeResponse(String.self, from: response)
            case .failure(let failure):
                return Result.failure(ApiError.encoding(failure.localizedDescription))
            }
        },
        getDistricts: { regionId in
            let response = await performGetRequest(
                path: "/regions/\(regionId)/districts",
            )
            return decodeResponse([PublicDistrict].self, from: response)
        },
        getDistrict: { id in
            let response = await performGetRequest(
                path: "/districts/\(id)",
                query: ["id":id]
            )
            return decodeResponse(PublicDistrict.self, from: response)
        },
        postDistrict: { district, accessToken in
            let body = encodeRequest(district)
            switch body {
            case .success(let body):
                let response = await performPostRequest(path: "/districts", body: body,accessToken: accessToken)
                return decodeResponse(String.self, from: response)
            case .failure(let failure):
                return Result.failure(ApiError.encoding(failure.localizedDescription))
            }
        },
        putDistrict: { district, accessToken in
            let body = encodeRequest(district)
            switch body {
            case .success(let body):
                let response = await performPutRequest(path: "/districts/\(district.id)", body: body,accessToken: accessToken)
                return decodeResponse(String.self, from: response)
            case .failure(let failure):
                return Result.failure(ApiError.encoding(failure.localizedDescription))
            }
        },
        getRoutes: { districtId in
            let response = await performGetRequest(
                path: "/districts/\(districtId)/route",
                query: ["districtId":districtId]
            )
            return decodeResponse([RouteSummary].self, from: response)
        },
        getRoute: { districtId, date, title in
            var query:[String:Any] = [
                "year":date.year,
                "month":date.month,
                "day":date.day,
                "title":title
            ]
            let response = await performGetRequest(
                path: "/districts/\(districtId)/routes",
                query: query
            )
            return decodeResponse(PublicRoute.self, from: response)
        },
        getCurrentRoute: { districtId in
            let response = await performGetRequest(
                path: "/district/\(districtId)/routes",
            )
            return decodeResponse(PublicRoute.self, from: response)
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
        putRoute: { route, accessToken in
            let body = encodeRequest(route)
            switch body {
            case .success(let body):
                let response = await performPostRequest(path: "/route/\(route.districtId)/\(route.date.text())/\(route.title)", body: body,accessToken: accessToken)
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
        getLocation: { districtId in
            let response = await performGetRequest(
                path: "/locations/\(districtId)",
            )
            return decodeResponse(PublicLocation?.self, from: response)
        },
        getLocations: { districtId in
            let response = await performGetRequest(
                path: "/locations"
            )
            return decodeResponse([PublicLocation].self, from: response)
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
}

private func decodeResponse<T:Codable>(_ type:T.Type, from response: Result<Data,Error>)->Result<T,ApiError>{
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
private func encodeRequest<T: Encodable>(_ object: T) -> Result<Data, Error> {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted // オプション: JSONを見やすくする
    do {
        let data = try encoder.encode(object)
        return .success(data)
    } catch {
        return .failure(error)
    }
}
