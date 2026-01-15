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
    let point: Point
    @FetchOne var performance: Performance?
    
    var title: String {
        point.anchor?.text ?? performance?.name ?? "情報なし"
    }
    
    init(_ point: Point) {
        self.point = point
        self._performance = FetchOne(Performance.where{ $0.id == point.performanceId })
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16){
            BulletItem(text: title)
            if let time = point.time {
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
