import AWSCognitoIdentityProvider
import Dependencies
import Foundation
import Shared
import Testing
@testable import Backend

struct AuthMiddlewareTest {
    @Test
    func invalidAccessToken_認証失敗として401を返して後続処理を実行しない() async throws {
        let authManager = AuthManagerMock(getAccessTokenHandler: { _ in
            throw NotAuthorizedException(message: "Invalid access token")
        })
        let routeController = RouteControllerMock()
        let app = make(routeController: routeController)

        let request = Application.Request.make(
            method: .get,
            path: "/routes/route-1",
            headers: ["authorization": "Bearer invalid-token"]
        )
        let response = await withDependencies {
            $0[AuthManagerFactoryKey.self] = { authManager }
        } operation: {
            await app.handle(request)
        }

        #expect(response.statusCode == 401)
        #expect(response.headers["Content-Type"] == "application/json")
        let body = try JSONDecoder().decode(ErrorResponse.self, from: Data(response.body.utf8))
        #expect(body.message == "Unauthorized")
        #expect(body.localizedDescription == "Unauthorized")
        #expect(authManager.getAccessTokenCallCount == 1)
        #expect(routeController.getCallCount == 0)
    }

    @Test
    func authServiceFailure_500として扱う() async throws {
        let authManager = AuthManagerMock(getAccessTokenHandler: { _ in
            throw TestError.intentional
        })
        let routeController = RouteControllerMock()
        let app = make(routeController: routeController)

        let request = Application.Request.make(
            method: .get,
            path: "/routes/route-1",
            headers: ["authorization": "Bearer token"]
        )
        let response = await withDependencies {
            $0[AuthManagerFactoryKey.self] = { authManager }
        } operation: {
            await app.handle(request)
        }

        #expect(response.statusCode == 500)
        #expect(response.headers["Content-Type"] == "application/json")
        let body = try JSONDecoder().decode(ErrorResponse.self, from: Data(response.body.utf8))
        #expect(body.message == "Internal Server Error")
        #expect(authManager.getAccessTokenCallCount == 1)
        #expect(routeController.getCallCount == 0)
    }
}

private extension AuthMiddlewareTest {
    func make(
        routeController: RouteControllerMock
    ) -> Application {
        withDependencies {
            $0[RouteControllerKey.self] = routeController
            $0[PeriodControllerKey.self] = PeriodControllerMock()
        } operation: {
            Application {
                AuthMiddleware(path: "/")
                OtherRouter()
            }
        }
    }
}
