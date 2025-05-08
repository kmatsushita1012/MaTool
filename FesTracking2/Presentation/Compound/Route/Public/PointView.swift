//
//  PointView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/07.
//

import SwiftUI
import ComposableArchitecture

struct PointView: View {
    let store: StoreOf<PointFeature>
    
    var body: some View {
        VStack{
            BulletItem(text: store.point.title ?? "情報なし")
            if let description = store.point.description {
                BulletItem(text: description)
            }
            if let time = store.point.time {
                BulletItem(text: time.text)
            }
        }
    }
}


