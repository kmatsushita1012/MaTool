//
//  NetworkManager.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/02.
//

import Foundation
import Foundation

class NetworkManager {
    static let shared = NetworkManager()
    
    let session: URLSession
    
    private init() {
        // キャッシュディレクトリの設定
        let cacheSizeMemory = 512 * 1024 * 1024 // 512MB
        let cacheSizeDisk = 512 * 1024 * 1024 // 512MB
        let cache = URLCache(memoryCapacity: cacheSizeMemory, diskCapacity: cacheSizeDisk, diskPath: "myCache")
        
        // URLSessionConfigurationの設定
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = cache
        configuration.requestCachePolicy = .useProtocolCachePolicy
        
        // URLSessionの作成
        self.session = URLSession(configuration: configuration)
    }
}
