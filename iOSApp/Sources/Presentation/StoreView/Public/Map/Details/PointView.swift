//
//  PointView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/08/05.
//

import SwiftUI
import Shared
import SQLiteData

struct PointView: View {
    let entry: PointEntry
    
    var title: String {
        entry.anchor?.text ?? entry.performance?.name ?? "情報なし"
    }
    
    init(_ entry: PointEntry) {
        self.entry = entry
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16){
            BulletItem(text: title)
            if let time = entry.time {
                BulletItem(text: time.text)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .safeAreaInset(edge: .top) {
            Color.clear.frame(height: 0)
        }
        
    }
}
