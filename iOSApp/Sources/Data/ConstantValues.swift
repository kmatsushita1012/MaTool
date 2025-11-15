//
//  ConstantValues.swift
//  MaTool
//
//  Created by 松下和也 on 2025/11/12.
//
import Dependencies

extension DependencyValues {
  var values: ConstantValues {
    get { self[ConstantValues.self] }
    set { self[ConstantValues.self] = newValue }
  }
}

struct ConstantValues:Sendable {
    let apiBaseUrl: String
    let appStatusUrl: String
    let defaultFestivalKey: String
    let defaultDistrictKey: String
    let loginIdKey: String
    let hasLaunchedBeforeKey: String
    let userGuideUrl: String
    let contactURL: String
}

extension ConstantValues: DependencyKey {
    static let liveValue = Self(
        apiBaseUrl: "https://eqp8rvam4h.execute-api.ap-northeast-1.amazonaws.com",
        appStatusUrl: "https://studiomk-app-assets.s3.ap-northeast-1.amazonaws.com/MaTool/app-config.json",
        defaultFestivalKey: "region",
        defaultDistrictKey: "district",
        loginIdKey: "login",
        hasLaunchedBeforeKey: "hasLaunchedBefore",
        userGuideUrl: "https://s3.ap-northeast-1.amazonaws.com/studiomk.documents/userguides/matool.pdf",
        contactURL: "https://forms.gle/ppaAwkqrFPKiC9mr8"
    )
}

