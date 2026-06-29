//
//  PresentationError.swift
//  MaTool
//
//  Created by 松下和也 on 2026/02/24.
//

enum PresentationError: Error{
    case notFound

    var appError: AppError {
        switch self {
        case .notFound:
            return .export(.notFound("必要な情報の取得に失敗しました。"))
        }
    }
}
