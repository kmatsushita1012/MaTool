//
//  APIGateway.swift
//  MaToolAPI
//
//  Created by 松下和也 on 2025/11/07.
//

import Foundation
import AWSLambdaEvents
import AWSLambdaRuntime

protocol APIGateway: Sendable {
    static var app: Application { get }
    static func main() async throws
    static func handler(request: APIGatewayV2Request, context: LambdaContext) async throws -> APIGatewayV2Response
}

extension APIGateway {
    static func main() async throws {
        let runtime = LambdaRuntime {
            (request: APIGatewayV2Request, context: LambdaContext) in
            try await self.handler(request: request, context: context)
        }

        // start the loop
        try await runtime.run()
    }
    
    static func handler(request: APIGatewayV2Request, context: LambdaContext) async throws -> APIGatewayV2Response {
        if let jsonData = try? JSONEncoder().encode(request),
            let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        }
        
        let res = await app.handle(
            .init(
                method: Application.Method(rawValue: request.context.http.method.rawValue),
                path: request.routePath,
                headers: request.headers,
                parameters: request.queryStringParameters,
                body: request.body
            )
        )

        return APIGatewayV2Response(
            statusCode: .init(code: res.statusCode),
            headers: res.headers,
            body: res.body
        )
    }
}

extension APIGatewayV2Request {
    var routePath: String {
        guard let proxyPath = pathParameters["proxy"] else {
            return rawPath
        }
        return "/\(proxyPath)"
    }
}
