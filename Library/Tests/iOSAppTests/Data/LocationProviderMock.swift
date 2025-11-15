//
//  LocationProviderMock.swift
//  MaTool
//
//  Created by 松下和也 on 2025/11/12.
//


extension LocationProviderKey: TestDependencyKey {
    static let testValue: LocationProviderProtocol = LocationProvider() // 仮
}
