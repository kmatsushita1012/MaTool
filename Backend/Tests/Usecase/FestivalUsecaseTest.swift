//
//  FestivalUsecaseTest.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/11/23.
//

import Testing
import Dependencies
@testable import Backend
import Shared

// TODO: テスト
struct FestivalUsecaseTest {
    @Test func test_get_正常() async throws {
        let festival = Festival(id: "g-id", name: "g-name", subname: "g-subname", prefecture: "p", city: "c", base: Coordinate(latitude: 0.0, longitude: 0.0))
        let expected = FestivalPack(festival: festival, checkpoints: [], hazardSections: [])
        
        var lastCalledId: String? = nil
        let mock = FestivalRepositoryMock(getHandler: { id in
            lastCalledId = id
            return festival
        })
        let subject = make(mock)
        
        
        let result = try await subject.get("g-id")
        
        
        #expect(result == expected)
        #expect(lastCalledId == "g-id")
        #expect(mock.getCallCount == 1)
    }
    
    @Test func test_get_異常() async throws {
        let expected = Error.internalServerError("get_failed")
        var lastCalledId: String? = nil
        let mock = FestivalRepositoryMock(getHandler: { id in
            lastCalledId = id
            throw expected
        })
        let subject = make(mock)
        
        
        await #expect(throws: expected){
            let _ = try await subject.get("festival-id")
        }
        
        
        #expect(lastCalledId == "festival-id")
        #expect(mock.getCallCount == 1)
    }

    @Test func test_scan_正常() async throws {
        let expected = Festival(id: "s-id", name: "s-name", subname: "s-subname", prefecture: "p", city: "c", base: Coordinate(latitude: 0, longitude: 0))
        let mock = FestivalRepositoryMock(scanHandler: {
            return [expected]
        })
        let subject = make(mock)


        let result = try await subject.scan()


        #expect(result.count == 1)
        #expect(result.first == expected)
        #expect(mock.scanCallCount == 1)
    }

    @Test func test_scan_異常() async throws {
        let expected = Error.internalServerError("scan_failed")
        let mock = FestivalRepositoryMock(scanHandler: {
            throw expected
        })
        let subject = make(mock)


        await #expect(throws: expected) {
            let _ = try await subject.scan()
        }


        #expect(mock.scanCallCount == 1)
    }

    @Test func test_put_正常() async throws {
        let festival = Festival(id: "p-id", name: "p-name", subname: "p-subname", prefecture: "p", city: "c", base: Coordinate(latitude: 0, longitude: 0))
        let pack = FestivalPack(festival: festival, checkpoints: [], hazardSections: [])
        let mock = FestivalRepositoryMock(putHandler: { festival in
            return festival
        })
        let subject = make(mock)


        let result = try await subject.put(pack, user: .headquarter("p-id"))


        #expect(result == pack)
        #expect(mock.putCount == 1)
    }
    
    @Test func test_put_ロールが違う() async throws {
        let festival = Festival(id: "p-id", name: "p-name", subname: "p-subname", prefecture: "p", city: "c", base: Coordinate(latitude: 0, longitude: 0))
        let pack = FestivalPack(festival: festival, checkpoints: [], hazardSections: [])
        let expected = Error.unauthorized("アクセス権限がありません。")
        let mock = FestivalRepositoryMock(putHandler: { _ in
            throw expected
        })
        let subject = make(mock)


        await #expect(throws: expected) {
            let _ = try await subject.put(pack, user: .district("different-id"))
        }


        #expect(mock.putCount == 0)
    }
    
    @Test func test_put_idが違う() async throws {
        let festival = Festival(id: "p-id", name: "p-name", subname: "p-subname", prefecture: "p", city: "c", base: Coordinate(latitude: 0, longitude: 0))
        let pack = FestivalPack(festival: festival, checkpoints: [], hazardSections: [])
        let expected = Error.unauthorized("アクセス権限がありません。")
        let mock = FestivalRepositoryMock(putHandler: { _ in
            throw expected
        })
        let subject = make(mock)


        await #expect(throws: expected) {
            let _ = try await subject.put(pack, user: .headquarter("different-id"))
        }


        #expect(mock.putCount == 0)
    }
    
    @Test func test_put_異常() async throws {
        let festival = Festival(id: "p-id", name: "p-name", subname: "p-subname", prefecture: "p", city: "c", base: Coordinate(latitude: 0, longitude: 0))
        let pack = FestivalPack(festival: festival, checkpoints: [], hazardSections: [])
        let expected = Error.internalServerError("put_failed")
        let mock = FestivalRepositoryMock(putHandler: { _ in
            throw expected
        })
        let subject = make(mock)


        await #expect(throws: expected) {
            let _ = try await subject.put(pack, user: .headquarter("p-id"))
        }


        #expect(mock.putCount == 1)
    }
}

extension FestivalUsecaseTest {
    func make(_ repository: FestivalRepositoryMock = .init()) -> FestivalUsecase{
        let subject = withDependencies({
            $0[FestivalRepositoryKey.self] = repository
        }){
            FestivalUsecase()
        }
        return subject
    }
}
