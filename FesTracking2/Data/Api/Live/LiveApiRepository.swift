//
//  LiveRepository.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/02.
//

import Foundation
import Dependencies

let base = "https://eqp8rvam4h.execute-api.ap-northeast-1.amazonaws.com"

extension ApiRepotiroy: DependencyKey {
    static let liveValue = Self(
        getRegions: {
            let response = await performGetRequest(
                base: base,
                path: "/regions"
            )
            return decodeResponse([Region].self, from: response)
        },
        getRegion: { id in
            let response = await performGetRequest(
                base: base,
                path: "/regions/\(id)"
            )
            return decodeResponse(Region.self, from: response)
        },
        putRegion: { region, accessToken in
            let body = encodeRequest(region)
            switch body {
            case .success(let body):
                let response = await performPutRequest(
                    base: base,
                    path: "/regions/\(region.id)",
                    body: body,
                    accessToken: accessToken
                )
                return decodeResponse(String.self, from: response)
            case .failure(let failure):
                return Result.failure(ApiError.encoding(failure.localizedDescription))
            }
        },
        getDistricts: { regionId in
            let response = await performGetRequest(
                base: base,
                path: "/regions/\(regionId)/districts"
            )
            return decodeResponse([PublicDistrict].self, from: response)
        },
        getDistrict: { id in
            let response = await performGetRequest(
                base: base,
                path: "/districts/\(id)"
            )
            return decodeResponse(PublicDistrict.self, from: response)
        },
        postDistrict: { regionId, districtName, email, accessToken in
            let body = encodeRequest(
                [
                    "name": districtName,
                    "email": email
                ]
            )
            switch body {
            case .success(let body):
                let response = await performPostRequest(
                    base: base,
                    path: "/regions/\(regionId)/districts",
                    body: body,
                    accessToken: accessToken
                    )
                return decodeResponse(String.self, from: response)
            case .failure(let failure):
                return Result.failure(ApiError.encoding(failure.localizedDescription))
            }
        },
        putDistrict: { district, accessToken in
            let body = encodeRequest(district)
            switch body {
            case .success(let body):
                let response = await performPutRequest(
                    base: base,
                    path: "/districts/\(district.id)",
                    body: body, 
                    accessToken: accessToken
                )
                return decodeResponse(String.self, from: response)
            case .failure(let failure):
                return Result.failure(ApiError.encoding(failure.localizedDescription))
            }
        },
        getTool: { districtId, accessToken in
            let response = await performGetRequest(
                base: base,
                path: "/districts/\(districtId)/tools",
                accessToken: accessToken
            )
            return decodeResponse(DistrictTool.self, from: response)
        },
        getRoutes: { districtId, accessToken in
            let response = await performGetRequest(
                base: base,
                path: "/districts/\(districtId)/routes",
                accessToken: accessToken
            )
            return decodeResponse([RouteSummary].self, from: response)
        },
        getRoute: { id, accessToken in
            let response = await performGetRequest(
                base: base,
                path: "/routes/\(id)",
                accessToken: accessToken
            )
            return decodeResponse(PublicRoute.self, from: response)
        },
        getCurrentRoute: { districtId, accessToken in
            let response = await performGetRequest(
                base: base,
                path: "/districts/\(districtId)/routes/current",
                accessToken: accessToken
            )
            return decodeResponse(PublicRoute.self, from: response)
        },
        postRoute: { route, accessToken in
            print(route)
            let body = encodeRequest(route)
            switch body {
            case .success(let body):
                let response = await performPostRequest(
                    base: base,
                    path: "/districts/\(route.districtId)/routes",
                    body: body,
                    accessToken: accessToken
                    )
                return decodeResponse(String.self, from: response)
            case .failure(let failure):
                return Result.failure(ApiError.encoding(failure.localizedDescription))
            }
        },
        putRoute: { route, accessToken in
            let body = encodeRequest(route)
            switch body {
            case .success(let body):
                let response = await performPutRequest(
                    base: base,
                    path: "/routes/\(route.id)",
                    body: body,
                    accessToken: accessToken
                )
                return decodeResponse(String.self, from: response)
            case .failure(let failure):
                return Result.failure(ApiError.encoding(failure.localizedDescription))
            }
        },
        deleteRoute: { id, accessToken in
            let response = await performDeleteRequest(
                base: base,
                path: "/routes/\(id)",
                accessToken: accessToken
            )
            return decodeResponse(String.self, from: response)
        },
        getLocation: { districtId, accessToken in
            let response = await performGetRequest(
                base: base,
                path: "/districts/\(districtId)/locations",
                accessToken: accessToken
            )
            return decodeResponse(PublicLocation?.self, from: response)
        },
        getLocations: { regionId, accessToken in
            let response = await performGetRequest(
                base: base,
                path: "/regions/\(regionId)/locations",
                accessToken: accessToken
            )
            return decodeResponse([PublicLocation].self, from: response)
        },
        putLocation: { location, accessToken in
            let body = encodeRequest(location)
            switch body {
            case .success(let body):
                let response = await performPutRequest(
                    base: base,
                    path: "/districts/\(location.districtId)/locations",
                    body: body,
                    accessToken: accessToken
                    )
                return decodeResponse(String.self, from: response)
            case .failure(let failure):
                return Result.failure(ApiError.encoding(failure.localizedDescription))
            }
        },
        deleteLocation: { id, accessToken in
            let response = await performDeleteRequest(
                base: base,
                path: "/districts/\(id)/locations",
                accessToken: accessToken
            )
            return decodeResponse(String.self, from: response)
        },
        getSegmentCoordinate: { coordinate1, coordinate2 in
            let response = await performGetRequest(
                base: base,
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
            print(error)
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
