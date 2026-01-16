//
//  Others.swift
//  MaTool
//
//  Created by 松下和也 on 2026/01/16.
//

import Shared

enum LaunchState: Entity {
    case district(Route.ID?) // ホーム画面&町登録あり
    case festival // ホーム画面&町登録なし
    case onboarding
    case loading
}
