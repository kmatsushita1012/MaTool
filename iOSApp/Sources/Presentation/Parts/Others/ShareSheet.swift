//
//  ShareSheet.swift
//  MaTool
//
//  Created by 松下和也 on 2025/07/31.
//

import SwiftUI

struct ShareSheet<T>: UIViewControllerRepresentable {
    let items: [T]
    
    init(items: [T]){
        self.items = items
    }
    
    init(item: T){
        self.items = [item]
    }
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ExportedFolder: Identifiable, Equatable {
    let id = UUID()
    let files: [URL]
    
    init(_ files: [URL]){
        self.files = files
    }
}

struct ExportedItem: Identifiable, Equatable {
    let id = UUID()
    let image: UIImage
    let url: URL
}
