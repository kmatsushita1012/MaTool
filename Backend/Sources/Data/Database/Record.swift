//
//  Record.swift
//  matool-backend
//
//  Created by 松下和也 on 2026/01/08.
//

import Shared

// MARK: - RecordProtocol
protocol RecordProtocol: Entity {
    associatedtype Content: Entity
    
    var pk: String { get }
    var sk: String { get }    
    var content: Content { get }
}

// MARK: - Record
struct Record<Content: Entity>: RecordProtocol {
    let pk:  String
    let sk: String
    let content: Content
}
