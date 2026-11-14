import AWSLambdaEvents
import Foundation
import Testing
@testable import Backend

struct APIGatewayTests {
    @Test("Proxyルートが存在する場合はProxyパラメータをパスとして優先する")
    func routePathUsesProxyParameter() throws {
        let request = try makeRequest(rawPath: "/my/raw/path", proxy: "district/route")

        #expect(request.rawPath == "/my/raw/path")
        #expect(request.routePath == "/district/route")
    }

    @Test("Proxyパラメータが存在しない場合は生のリクエストパスを保持する")
    func routePathFallsBackToRawPath() throws {
        let request = try makeRequest(rawPath: "/festival/route", proxy: nil)

        #expect(request.routePath == "/festival/route")
    }

    private func makeRequest(rawPath: String, proxy: String?) throws -> APIGatewayV2Request {
        let parameters = proxy.map { ["proxy": $0] } ?? [:]
        let data = try JSONSerialization.data(withJSONObject: [
            "version": "2.0",
            "routeKey": "$default",
            "rawPath": rawPath,
            "rawQueryString": "",
            "headers": [String: String](),
            "queryStringParameters": [String: String](),
            "pathParameters": parameters,
            "requestContext": [
                "accountId": "123456789012",
                "apiId": "api-id",
                "domainName": "api.example.com",
                "domainPrefix": "api",
                "http": [
                    "method": "GET",
                    "path": rawPath,
                    "protocol": "HTTP/1.1",
                    "sourceIp": "127.0.0.1",
                    "userAgent": "unit-test"
                ],
                "requestId": "request-id",
                "routeKey": "$default",
                "stage": "$default",
                "time": "12/Mar/2026:19:03:58 +0000",
                "timeEpoch": 1_773_252_238_000
            ] as [String: Any],
            "isBase64Encoded": false
        ] as [String: Any])
        return try JSONDecoder().decode(APIGatewayV2Request.self, from: data)
    }
}
