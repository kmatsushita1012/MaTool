import iOSShared
//
//  ShareSheet.swift
//  MaTool
//
//  Created by 松下和也 on 2025/07/31.
//

import SwiftUI

public struct ShareSheet<T>: UIViewControllerRepresentable {
    public let items: [T]
    
    public init(items: [T]){
        self.items = items
    }
    
    public init(item: T){
        self.items = [item]
    }
    
    public func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

public struct ExportedFolder: Identifiable, Equatable {
    public let id = UUID()
    public let files: [URL]
    
    public init(_ files: [URL]){
        self.files = files
    }
}

public struct ExportedItem: Identifiable, Equatable {
    public let id = UUID()
    public let image: UIImage
    public let url: URL

    public init(image: UIImage, url: URL) {
        self.image = image
        self.url = url
    }
}
