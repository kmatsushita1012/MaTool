//
//  ShareSheet.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/07/31.
//

import SwiftUI

struct ShareSheet<T>: UIViewControllerRepresentable {
    let items: [T]
    
    init(_ items: [T]){
        self.items = items
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
