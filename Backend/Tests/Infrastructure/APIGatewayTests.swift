import Testing
@testable import Backend

struct APIGatewayTests {
    @Test("Proxyルートを受け取った場合は先頭スラッシュ付きでパスに優先する")
    func routePathUsesProxyParameter() {
        #expect(
            APIGatewayRoutePath.resolve(rawPath: "/raw/path", proxyPath: "district/route")
                == "/district/route"
        )
        #expect(
            APIGatewayRoutePath.resolve(rawPath: "/raw/path", proxyPath: "")
                == "/"
        )
    }

    @Test("Proxyパラメータが無い場合は生のリクエストパスを使う")
    func routePathFallsBackToRawPath() {
        #expect(
            APIGatewayRoutePath.resolve(rawPath: "/festival/route", proxyPath: nil)
                == "/festival/route"
        )
    }
}
