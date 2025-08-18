//
//  PointView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/08/05.
//

import SwiftUI

struct PointView: View {
    
    let item: Point
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16){
            BulletItem(text: item.title ?? "情報なし")
            if let description = item.description {
                BulletItem(text: description)
            }
            if let time = item.time {
                BulletItem(text: time.text)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}
