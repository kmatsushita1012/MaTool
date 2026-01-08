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
    
    init(pk: String, sk: String, content: Content) {
        self.pk = pk
        self.sk = sk
        self.content = content
    }
}

// TODO: マイグレーション後に削除
extension Record where Content: Identifiable {
    init(_ content: Content){
        self.init(pk: content.id as! String, sk: "", content: content)
    }
}
