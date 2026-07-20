//
//  PublicMapAdPolicyTests.swift
//  MaToolTests
//
//  Created by Codex on 2026/06/30.
//

import XCTest
@testable import iOSApp

final class PublicMapAdPolicyTests: XCTestCase {
    func test本部権限では広告表示しない() {
        let counter = PublicMapAdCounter(eligibleEventCount: 2)
        let decision = PublicMapAdPolicy.evaluate(
            userRole: .headquarter("festival"),
            targetDistrictId: "district-b",
            favoriteDistrictId: "district-a",
            counter: counter
        )

        XCTAssertEqual(decision.counter, counter)
        XCTAssertFalse(decision.shouldShowInterstitial)
    }

    func testお気に入り町ではカウントしない() {
        let counter = PublicMapAdCounter(eligibleEventCount: 2)
        let decision = PublicMapAdPolicy.evaluate(
            userRole: .guest,
            targetDistrictId: "district-a",
            favoriteDistrictId: "district-a",
            counter: counter
        )

        XCTAssertEqual(decision.counter, counter)
        XCTAssertFalse(decision.shouldShowInterstitial)
    }

    func testお気に入り外の町では3回に1回表示する() {
        let decision = PublicMapAdPolicy.evaluate(
            userRole: .guest,
            targetDistrictId: "district-b",
            favoriteDistrictId: "district-a",
            counter: .init(eligibleEventCount: 2)
        )

        XCTAssertEqual(decision.counter.eligibleEventCount, 3)
        XCTAssertTrue(decision.shouldShowInterstitial)
    }

    func testお気に入りも権限もない場合は最初の5回をスキップする() {
        let decision = PublicMapAdPolicy.evaluate(
            userRole: .guest,
            targetDistrictId: "district-a",
            favoriteDistrictId: nil,
            counter: .init(eligibleEventCount: 4)
        )

        XCTAssertEqual(decision.counter.eligibleEventCount, 5)
        XCTAssertFalse(decision.shouldShowInterstitial)
    }

    func testお気に入りも権限もない場合は6回目で表示する() {
        let decision = PublicMapAdPolicy.evaluate(
            userRole: .guest,
            targetDistrictId: "district-a",
            favoriteDistrictId: nil,
            counter: .init(eligibleEventCount: 5)
        )

        XCTAssertEqual(decision.counter.eligibleEventCount, 6)
        XCTAssertTrue(decision.shouldShowInterstitial)
    }

    func test各町権限の自町は除外する() {
        let counter = PublicMapAdCounter(eligibleEventCount: 1)
        let decision = PublicMapAdPolicy.evaluate(
            userRole: .district("district-a"),
            targetDistrictId: "district-a",
            favoriteDistrictId: nil,
            counter: counter
        )

        XCTAssertEqual(decision.counter, counter)
        XCTAssertFalse(decision.shouldShowInterstitial)
    }
}
