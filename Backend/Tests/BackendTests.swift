//
//  BackendTests.swift
//  MaTool
//
//  Created by 松下和也 on 2025/10/30.
//

import Testing
@testable import Backend

struct BackendTests{
    @Test func test_成功する() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
        let count = 5
        #expect(count == 5)
    }

    @Test func test＿失敗する() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
        let count = 5
        #expect(count == 4)
    }
}
