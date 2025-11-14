//
//  DistrictRepositoryTest.swift
//  MaTool
//
//  Created by 松下和也 on 2025/11/14.
//

import Testing
import Dependencies
import Shared
@testable import Backend

struct DistrictRepositoryTest {
    
    let subject: DistrictRepository = withDependencies {
        let response = District(id: "id", name: "name", festivalId: "festivalId", visibility: .all)
        $0.dataStoreFactory = { _ in DataStoreMock<String, District>(response: response) }
    } operation: {
        DistrictRepository()
    }
    
    @Test func test_get_正常() async {
        
    }
}
