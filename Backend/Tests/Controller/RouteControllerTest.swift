//
//  RouteControllerTest.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/11/30.
//
//
//  RouteControllerTest.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/11/30.
//

import Foundation
import Testing
@testable import Backend
import Dependencies
import Shared


struct RouteControllerTest {
	let next: Handler = { _ in
		throw TestError.unimplemented
	}
	let expectedHeaders: [String: String] = ["Content-Type": "application/json"]

	@Test func test_query_正常() async throws {
		let route = Route(id: "r-id", districtId: "d-id", start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
		let expected = [RouteItem(from: route)]
		var lastCalledDistrictId: String? = nil
		var lastCalledUser: UserRole? = nil
		let mock = RouteUsecaseMock(queryHandler: { districtId, user in
			lastCalledDistrictId = districtId
			lastCalledUser = user
			return expected
		})
		let subject = makeUsecase(mock)
		let request = makeRequest(method: .get, parameters: ["districtId": "d-id"]) 


		let result = try await subject.query(request, next: next)


		#expect(result.statusCode == 200)
		#expect(result.headers == expectedHeaders)
		let target = try [RouteItem].from(result.body)
		#expect(target == expected)
		#expect(lastCalledDistrictId == "d-id")
		#expect(lastCalledUser == .guest)
		#expect(mock.queryCallCount == 1)
	}
    
    @Test func test_query_userがnil() async throws {
        let route = Route(id: "r-id", districtId: "d-id", start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
        let expected = [RouteItem(from: route)]
        var lastCalledDistrictId: String? = nil
        var lastCalledUser: UserRole? = nil
        let mock = RouteUsecaseMock(queryHandler: { districtId, user in
            lastCalledDistrictId = districtId
            lastCalledUser = user
            return expected
        })
        let subject = makeUsecase(mock)
        var request = makeRequest(method: .get, parameters: ["districtId": "d-id"])
        request.user = nil

        let result = try await subject.query(request, next: next)

        #expect(result.statusCode == 200)
        #expect(result.headers == expectedHeaders)
        let target = try [RouteItem].from(result.body)
        #expect(target == expected)
        #expect(lastCalledDistrictId == "d-id")
        #expect(lastCalledUser == .guest)
        #expect(mock.queryCallCount == 1)
    }

	@Test func test_query_異常() async throws {
		let expectedError = Error.internalServerError("query_failed")
		var lastCalledDistrictId: String? = nil
		var lastCalledUser: UserRole? = nil
		let mock = RouteUsecaseMock(queryHandler: { districtId, user in
			lastCalledDistrictId = districtId
			lastCalledUser = user
			throw expectedError
		})
		let subject = makeUsecase(mock)
		let request = makeRequest(method: .get, parameters: ["districtId": "d-id"]) 


		await #expect(throws: expectedError) {
			let _ = try await subject.query(request, next: next)
		}


		#expect(lastCalledDistrictId == "d-id")
		#expect(lastCalledUser == .guest)
		#expect(mock.queryCallCount == 1)
	}

	@Test func test_get_正常() async throws {
		let route = Route(id: "r-id", districtId: "d-id", start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
		var lastCalledId: String? = nil
		let mock = RouteUsecaseMock(getHandler: { id, _ in
			lastCalledId = id
			return route
		})
		let subject = makeUsecase(mock)
		let request = makeRequest(method: .get, parameters: ["routeId": "r-id"]) 


		let result = try await subject.get(request, next: next)


		#expect(lastCalledId == "r-id")
		#expect(result.statusCode == 200)
		#expect(result.headers == expectedHeaders)
		let target = try Route.from(result.body)
		#expect(target == route)
		#expect(mock.getCallCount == 1)
	}
    
    @Test func test_get_user_nil() async throws {
        let route = Route(id: "r-id", districtId: "d-id", start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
        var lastCalledId: String? = nil
        var lastCalledUser: UserRole? = nil
        let mock = RouteUsecaseMock(getHandler: { id, user in
            lastCalledId = id
            lastCalledUser = user
            return route
        })
        let subject = makeUsecase(mock)
        var request = makeRequest(method: .get, parameters: ["routeId": "r-id"])
        request.user = nil

        let result = try await subject.get(request, next: next)

        #expect(lastCalledId == "r-id")
        #expect(lastCalledUser == .guest)
        #expect(result.statusCode == 200)
        #expect(result.headers == expectedHeaders)
        let target = try Route.from(result.body)
        #expect(target == route)
        #expect(mock.getCallCount == 1)
    }

	@Test func test_get_異常() async throws {
		let expectedError = Error.internalServerError("get_failed")
		var lastCalledId: String? = nil
		let mock = RouteUsecaseMock(getHandler: { id, _ in
			lastCalledId = id
			throw expectedError
		})
		let subject = makeUsecase(mock)
		let request = makeRequest(method: .get, parameters: ["routeId": "r-id"]) 


		await #expect(throws: expectedError) {
			let _ = try await subject.get(request, next: next)
		}


		#expect(lastCalledId == "r-id")
		#expect(mock.getCallCount == 1)
	}

	@Test func test_getCurrent_正常() async throws {
		let route = Route(id: "r-id", districtId: "d-id", start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
		let item = RouteItem(from: route)
		let expected = CurrentResponse(districtId: "d-id", districtName: "d-name", routes: [item], current: route, location: nil)
		var lastCalledDistrictId: String? = nil
		var lastCalledUser: UserRole? = nil
		let mock = RouteUsecaseMock(getCurrentHandler: { districtId, user, _ in
			lastCalledDistrictId = districtId
			lastCalledUser = user
			return expected
		})
		let subject = makeUsecase(mock)
		let request = makeRequest(method: .get, parameters: ["districtId": "d-id"], user: .district("d-id"))


		let result = try await subject.getCurrent(request, next: next)


		#expect(lastCalledDistrictId == "d-id")
		#expect(lastCalledUser == .district("d-id"))
		#expect(result.statusCode == 200)
		#expect(result.headers == expectedHeaders)
		let target = try CurrentResponse.from(result.body)
		#expect(target.districtId == expected.districtId)
		#expect(target.districtName == expected.districtName)
		#expect(mock.getCurrentCallCount == 1)
	}
    
    @Test func test_getCurrent_userがnil() async throws {
        let route = Route(id: "r-id", districtId: "d-id", start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
        let item = RouteItem(from: route)
        let expected = CurrentResponse(districtId: "d-id", districtName: "d-name", routes: [item], current: route, location: nil)
        var lastCalledDistrictId: String? = nil
        var lastCalledUser: UserRole? = nil
        let mock = RouteUsecaseMock(getCurrentHandler: { districtId, user, _ in
            lastCalledDistrictId = districtId
            lastCalledUser = user
            return expected
        })
        let subject = makeUsecase(mock)
        var request = makeRequest(method: .get, parameters: ["districtId": "d-id"])
        request.user = nil

        let result = try await subject.getCurrent(request, next: next)

        #expect(lastCalledDistrictId == "d-id")
        #expect(lastCalledUser == .guest)
        #expect(result.statusCode == 200)
        #expect(result.headers == expectedHeaders)
        let target = try CurrentResponse.from(result.body)
        #expect(target.districtId == expected.districtId)
        #expect(target.districtName == expected.districtName)
        #expect(mock.getCurrentCallCount == 1)
    }


	@Test func test_getCurrent_異常() async throws {
		let expectedError = Error.internalServerError("getCurrent_failed")
		var lastCalledDistrictId: String? = nil
		var lastCalledUser: UserRole? = nil
		let mock = RouteUsecaseMock(getCurrentHandler: { districtId, user, _ in
			lastCalledDistrictId = districtId
			lastCalledUser = user
			throw expectedError
		})
		let subject = makeUsecase(mock)
		let request = makeRequest(method: .get, parameters: ["districtId": "d-id"], user: .district("d-id"))


		await #expect(throws: expectedError) {
			let _ = try await subject.getCurrent(request, next: next)
		}


		#expect(lastCalledDistrictId == "d-id")
		#expect(lastCalledUser == .district("d-id"))
		#expect(mock.getCurrentCallCount == 1)
	}

	@Test func test_getIds_正常() async throws {
		let expected = ["r-1", "r-2"]
		var lastCalledUser: UserRole? = nil
		let mock = RouteUsecaseMock(getAllRouteIdsHandler: { user in
			lastCalledUser = user
			return expected
		})
		let subject = makeUsecase(mock)
		let request = makeRequest(method: .get, user: .headquarter("f-id"))


		let result = try await subject.getIds(request, next: next)


		#expect(result.statusCode == 200)
		#expect(result.headers == expectedHeaders)
		let target = try [String].from(result.body)
		#expect(target == expected)
		#expect(lastCalledUser == .headquarter("f-id"))
		#expect(mock.getAllRouteIdsCallCount == 1)
	}
    
    @Test func test_getIds_userがnil() async throws {
        let expected = ["r-1", "r-2"]
        var lastCalledUser: UserRole? = nil
        let mock = RouteUsecaseMock(getAllRouteIdsHandler: { user in
            lastCalledUser = user
            return expected
        })
        let subject = makeUsecase(mock)
        var request = makeRequest(method: .get)
        request.user = nil

        let result = try await subject.getIds(request, next: next)

        #expect(result.statusCode == 200)
        #expect(result.headers == expectedHeaders)
        let target = try [String].from(result.body)
        #expect(target == expected)
        #expect(lastCalledUser == .guest)
        #expect(mock.getAllRouteIdsCallCount == 1)
    }

	@Test func test_getIds_異常() async throws {
		let expectedError = Error.internalServerError("getIds_failed")
		var lastCalledUser: UserRole? = nil
		let mock = RouteUsecaseMock(getAllRouteIdsHandler: { user in
			lastCalledUser = user
			throw expectedError
		})
		let subject = makeUsecase(mock)
		let request = makeRequest(method: .get, user: .headquarter("f-id"))


		await #expect(throws: expectedError) {
			let _ = try await subject.getIds(request, next: next)
		}


		#expect(lastCalledUser == .headquarter("f-id"))
		#expect(mock.getAllRouteIdsCallCount == 1)
	}

	@Test func test_post_正常() async throws {
		let route = Route(id: "r-id", districtId: "d-id", start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
		let body = try route.toString()
		var lastCalledDistrictId: String? = nil
		var lastCalledRoute: Route? = nil
		let mock = RouteUsecaseMock(postHandler: { districtId, route, _ in
			lastCalledDistrictId = districtId
			lastCalledRoute = route
			return route
		})
		let subject = makeUsecase(mock)
		let request = makeRequest(method: .post, parameters: ["districtId": "d-id"], user: .district("d-id"), body: body)


		let result = try await subject.post(request, next: next)


		#expect(lastCalledDistrictId == "d-id")
		#expect(lastCalledRoute?.id == route.id)
		#expect(result.statusCode == 200)
		#expect(result.headers == expectedHeaders)
		let target = try Route.from(result.body)
		#expect(target == route)
		#expect(mock.postCallCount == 1)
	}

    @Test func test_post_userがnil() async throws {
        let route = Route(id: "r-id", districtId: "d-id", start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
        let body = try route.toString()
        var lastCalledDistrictId: String? = nil
        var lastCalledRoute: Route? = nil
        var lastCalledUser: UserRole? = nil
        let mock = RouteUsecaseMock(postHandler: { districtId, route, user in
            lastCalledDistrictId = districtId
            lastCalledRoute = route
            lastCalledUser = user
            return route
        })
        let subject = makeUsecase(mock)
        var request = makeRequest(method: .post, parameters: ["districtId": "d-id"], body: body)
        request.user = nil

        
        let result = try await subject.post(request, next: next)

        
        #expect(lastCalledDistrictId == "d-id")
        #expect(lastCalledRoute?.id == route.id)
        #expect(lastCalledUser == .guest)
        #expect(result.statusCode == 200)
        #expect(result.headers == expectedHeaders)
        let target = try Route.from(result.body)
        #expect(target == route)
        #expect(mock.postCallCount == 1)
    }

	@Test func test_post_異常() async throws {
		let route = Route(id: "r-id", districtId: "d-id", start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
		let body = try route.toString()
		let expectedError = Error.internalServerError("post_failed")
		var lastCalledDistrictId: String? = nil
		var lastCalledRoute: Route? = nil
		let mock = RouteUsecaseMock(postHandler: { districtId, route, _ in
			lastCalledDistrictId = districtId
			lastCalledRoute = route
			throw expectedError
		})
		let subject = makeUsecase(mock)
		let request = makeRequest(method: .post, parameters: ["districtId": "d-id"], user: .district("d-id"), body: body)


		await #expect(throws: expectedError) {
			let _ = try await subject.post(request, next: next)
		}


		#expect(lastCalledDistrictId == "d-id")
		#expect(lastCalledRoute?.id == route.id)
		#expect(mock.postCallCount == 1)
	}

	@Test func test_put_正常() async throws {
		let route = Route(id: "r-id", districtId: "d-id", start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
		let body = try route.toString()
		var lastCalledId: String? = nil
		var lastCalledBody: Route? = nil
		var lastCalledUser: UserRole? = nil
		let mock = RouteUsecaseMock(putHandler: { id, item, user in
			lastCalledId = id
			lastCalledBody = item
			lastCalledUser = user
			return item
		})
		let subject = makeUsecase(mock)
		let request = makeRequest(method: .put, parameters: ["routeId": "r-id"], user: .district("d-id"), body: body)


		let result = try await subject.put(request, next: next)


		#expect(lastCalledId == "r-id")
		#expect(lastCalledBody == route)
		#expect(lastCalledUser == .district("d-id"))
		#expect(result.statusCode == 200)
		#expect(result.headers == expectedHeaders)
		let target = try Route.from(result.body)
		#expect(target == route)
	}
    
    @Test func test_put_userがnil() async throws {
        let route = Route(id: "r-id", districtId: "d-id", start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
        let body = try route.toString()
        var lastCalledId: String? = nil
        var lastCalledBody: Route? = nil
        var lastCalledUser: UserRole? = nil
        let mock = RouteUsecaseMock(putHandler: { id, item, user in
            lastCalledId = id
            lastCalledBody = item
            lastCalledUser = user
            return item
        })
        let subject = makeUsecase(mock)
        var request = makeRequest(method: .put, parameters: ["routeId": "r-id"], body: body)
        request.user = nil

        
        let result = try await subject.put(request, next: next)

        
        #expect(lastCalledId == "r-id")
        #expect(lastCalledBody == route)
        #expect(lastCalledUser == .guest)
        #expect(result.statusCode == 200)
        #expect(result.headers == expectedHeaders)
        let target = try Route.from(result.body)
        #expect(target == route)
    }

	@Test func test_put_異常() async throws {
		let route = Route(id: "r-id", districtId: "d-id", start: SimpleTime(hour: 10, minute: 0), goal: SimpleTime(hour: 11, minute: 0))
		let body = try route.toString()
		let expectedError = Error.internalServerError("put_failed")
		var lastCalledId: String? = nil
		var lastCalledBody: Route? = nil
		var lastCalledUser: UserRole? = nil
		let mock = RouteUsecaseMock(putHandler: { id, item, user in
			lastCalledId = id
			lastCalledBody = item
			lastCalledUser = user
			throw expectedError
		})
		let subject = makeUsecase(mock)
		let request = makeRequest(method: .put, parameters: ["routeId": "r-id"], user: .district("d-id"), body: body)


		await #expect(throws: expectedError) {
			let _ = try await subject.put(request, next: next)
		}


		#expect(lastCalledId == "r-id")
		#expect(lastCalledBody == route)
		#expect(lastCalledUser == .district("d-id"))
		#expect(mock.putCallCount == 1)
	}

	@Test func test_delete_正常() async throws {
		var lastCalledId: String? = nil
		var lastCalledUser: UserRole? = nil
		let mock = RouteUsecaseMock(deleteHandler: { id, user in
			lastCalledId = id
			lastCalledUser = user
		})
		let subject = makeUsecase(mock)
		let request = makeRequest(method: .delete, parameters: ["routeId": "r-id"], user: .district("d-id"))

		let result = try await subject.delete(request, next: next)

		#expect(lastCalledId == "r-id")
		#expect(lastCalledUser == .district("d-id"))
		#expect(result.statusCode == 200)
		#expect(result.headers == expectedHeaders)
		#expect(mock.deleteCallCount == 1)
	}

	@Test func test_delete_userがnil() async throws {
		var lastCalledId: String? = nil
		var lastCalledUser: UserRole? = nil
		let mock = RouteUsecaseMock(deleteHandler: { id, user in
			lastCalledId = id
			lastCalledUser = user
		})
		let subject = makeUsecase(mock)
		var request = makeRequest(method: .delete, parameters: ["routeId": "r-id"])
		request.user = nil

		let result = try await subject.delete(request, next: next)

		#expect(lastCalledId == "r-id")
		#expect(lastCalledUser == .guest)
		#expect(result.statusCode == 200)
		#expect(result.headers == expectedHeaders)
		#expect(mock.deleteCallCount == 1)
	}

	@Test func test_delete_異常_ルートが見つからない() async throws {
		let expectedError = Error.notFound("指定されたルートが見つかりません")
		let mock = RouteUsecaseMock(deleteHandler: { _, _ in
			throw expectedError
		})
		let subject = makeUsecase(mock)
		let request = makeRequest(method: .delete, parameters: ["routeId": "r-id"], user: .district("d-id"))

        
		await #expect(throws: expectedError) {
			let _ = try await subject.delete(request, next: next)
		}

        
		#expect(mock.deleteCallCount == 1)
	}

	@Test func test_delete_異常_ゲスト() async throws {
		let expectedError = Error.unauthorized("アクセス権限がありません")
		let mock = RouteUsecaseMock(deleteHandler: { _, _ in
			throw expectedError
		})
		let subject = makeUsecase(mock)
		let request = makeRequest(method: .delete, parameters: ["routeId": "r-id"], user: .guest)

        
		await #expect(throws: expectedError) {
			let _ = try await subject.delete(request, next: next)
		}

        
		#expect(mock.deleteCallCount == 1)
	}

	@Test func test_delete_異常_他人のDistrict() async throws {
		let expectedError = Error.unauthorized("アクセス権限がありません")
		let mock = RouteUsecaseMock(deleteHandler: { _, _ in
			throw expectedError
		})
		let subject = makeUsecase(mock)
		let request = makeRequest(method: .delete, parameters: ["routeId": "r-id"], user: .district("other-d-id"))

        
		await #expect(throws: expectedError) {
			let _ = try await subject.delete(request, next: next)
		}

        
		#expect(mock.deleteCallCount == 1)
	}

    
}

extension RouteControllerTest {
	private func makeUsecase(_ usecase: RouteUsecaseMock) -> RouteController{
		let  subject = withDependencies({
			$0[RouteUsecaseKey.self] = usecase
		}){
			RouteController()
		}
		return subject
	}

	private func makeRequest(
		method: Application.Method,
		path: String = "",
		parameters: [String : String] = [:],
		headers: [String : String] = [:],
		user: UserRole = .guest,
		body: String? = nil,
	) -> Request{
		return Request(method: method, path: path, headers: headers, parameters: parameters, user: user, body: body)
	}
}

