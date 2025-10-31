//
//  APIRepositoryImpl.swift
//  MaTool
//
//  Created by 松下和也 on 2025/03/02.
//

import Foundation
import Dependencies
import Shared

extension APIRepotiroy: DependencyKey {
    
    static let liveValue = {
        let authService = DependencyValues().authService
        let apiClient = DependencyValues().apiClient
        return Self(
            getFestivals: {
                let response = await apiClient.get(
                    path: "/regions"
                )
                return decodeResponse([Festival].self, from: response)
            },
            getFestival: { id in
                let response = await apiClient.get(
                    path: "/regions/\(id)"
                )
                return decodeResponse(Festival.self, from: response)
            },
            putFestival: { festival in
                let encodeResult = encodeRequest(festival)
                    .mapError { APIError.encoding(message: $0.localizedDescription) }
                let accessToken = await authService.getAccessToken()
                return await encodeResult.asyncFlatMap { body in
                    let response = await apiClient.put(
                        path: "/regions/\(festival.id)",
                        body: body,
                        accessToken: accessToken
                    )
                    return decodeResponse(String.self, from: response)
                }
            },
            getDistricts: { festivalId in
                let response = await apiClient.get(
                    path: "/regions/\(festivalId)/districts"
                )
                return decodeResponse([District].self, from: response)
            },
            getDistrict: { id in
                let response = await apiClient.get(
                    path: "/districts/\(id)"
                )
                return decodeResponse(District.self, from: response)
            },
            postDistrict: { festivalId, districtName, email in
                let encodeResult = encodeRequest(
                    [
                        "name": districtName,
                        "email": email
                    ]
                )
                let accessToken = await authService.getAccessToken()
                return await encodeResult.asyncFlatMap { body in
                    let response = await apiClient.post(
                        path: "/regions/\(festivalId)/districts",
                        body: body,
                        accessToken: accessToken
                    )
                    return decodeResponse(String.self, from: response)
                }
            },
            putDistrict: { district in
                let accessToken = await authService.getAccessToken()
                let encodeResult = encodeRequest(district)
                return await encodeResult.asyncFlatMap { body in
                    let response = await apiClient.put(
                        path: "/districts/\(district.id)",
                        body: body,
                        accessToken: accessToken
                    )
                    return decodeResponse(String.self, from: response)
                }
            },
            getTool: { districtId in
                let accessToken = await authService.getAccessToken()
                let response = await apiClient.get(
                    path: "/districts/\(districtId)/tools",
                    accessToken: accessToken
                )
                return decodeResponse(DistrictTool.self, from: response)
            },
            getRoutes: { districtId in
                let accessToken = await authService.getAccessToken()
                let response = await apiClient.get(
                    path: "/districts/\(districtId)/routes",
                    accessToken: accessToken,
                    isCache: true
                )
                return decodeResponse([RouteItem].self, from: response)
            },
            getRoute: { id in
                let accessToken = await authService.getAccessToken()
                let response = await apiClient.get(
                    path: "/routes/\(id)",
                    accessToken: accessToken,
                    isCache: false
                )
                return decodeResponse(Route.self, from: response)
            },
            getCurrentRoute: { districtId in
                let accessToken = await authService.getAccessToken()
                let response = await apiClient.get(
                    path: "/v2/districts/\(districtId)/routes/current",
                    accessToken: accessToken,
                    isCache: false
                )
                return decodeResponse(CurrentResponse.self, from: response)
            },
            getRouteIds: {
                let accessToken = await authService.getAccessToken()
                let response = await apiClient.get(
                    path: "/routes",
                    accessToken: accessToken,
                    isCache: false
                )
                return decodeResponse([String].self, from: response)
            },
            postRoute: { route in
                let encodeResult = encodeRequest(route)
                let accessToken = await authService.getAccessToken()
                return await encodeResult.asyncFlatMap { body in
                    let response = await apiClient.post(
                        path: "/districts/\(route.districtId)/routes",
                        body: body,
                        accessToken: accessToken
                    )
                    return decodeResponse(String.self, from: response)
                }
            },
            putRoute: { route in
                let encodeResult = encodeRequest(route)
                let accessToken = await authService.getAccessToken()
                return await encodeResult.asyncFlatMap { body in
                    let response = await apiClient.put(
                        path: "/routes/\(route.id)",
                        body: body,
                        accessToken: accessToken
                    )
                    return decodeResponse(String.self, from: response)
                }
            },
            deleteRoute: { id in
                let accessToken = await authService.getAccessToken()
                let response = await apiClient.delete(
                    path: "/routes/\(id)",
                    accessToken: accessToken
                )
                return decodeResponse(String.self, from: response)
            },
            getLocation: { districtId in
                let accessToken = await authService.getAccessToken()
                let response = await apiClient.get(
                    path: "/districts/\(districtId)/locations",
                    accessToken: accessToken,
                    isCache: false
                )
                return decodeResponse(FloatLocationGetDTO.self, from: response)
            },
            getLocations: { festivalId in
                let accessToken = await authService.getAccessToken()
                let response = await apiClient.get(
                    path: "/regions/\(festivalId)/locations",
                    accessToken: accessToken,
                    isCache: false
                )
                return decodeResponse([FloatLocationGetDTO].self, from: response)
            },
            putLocation: { location in
                let encodeResult = encodeRequest(location)
                let accessToken = await authService.getAccessToken()
                return await encodeResult.asyncFlatMap { body in
                    let response = await apiClient.put(
                        path: "/districts/\(location.districtId)/locations",
                        body: body,
                        accessToken: accessToken
                    )
                    return decodeResponse(String.self, from: response)
                }
            },
            deleteLocation: { id in
                let accessToken = await authService.getAccessToken()
                let response = await apiClient.delete(
                    path: "/districts/\(id)/locations",
                    accessToken: accessToken
                )
                return decodeResponse(String.self, from: response)
            }
        )
    }()
    
    static private func decodeResponse<T:Codable>(_ type:T.Type, from response: Result<Data,APIError>)->Result<T,APIError>{
        switch response {
        case .success(let data):
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let seconds = try container.decode(Double.self)
                return Date(timeIntervalSince1970: seconds)
            }
            do{
                let decodedObject = try decoder.decode(type, from: data)
                return Result.success(decodedObject)
            }catch{
                return Result.failure(APIError.decoding(message: "レスポンスの解析に失敗しました"))
            }
        case .failure(let error):
            return .failure(error)
        }
    }
    static private func encodeRequest<T: Encodable>(_ object: T) -> Result<Data, APIError> {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            let seconds = Int64(date.timeIntervalSince1970)
            try container.encode(seconds)
        }
        do {
            let data = try encoder.encode(object)
            return .success(data)
        } catch {
            return .failure(.encoding(message: "リクエストの生成に失敗しました"))
        }
    }
}
