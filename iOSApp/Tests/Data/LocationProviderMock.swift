//
//  LocationProviderMock.swift
//  MaTool
//
//  Created by 松下和也 on 2025/11/12.
//
import Dependencies
@testable import iOSApp


extension LocationProviderKey {
    static let testValue: LocationProviderProtocol = LocationProvider()
}
