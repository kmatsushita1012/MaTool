//
//  LocationView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/07.
//

import SwiftUI
import ComposableArchitecture


struct LocationView: View {
    let store: StoreOf<LocationFeature>
    
    var body: some View {
        VStack{
            BulletItem(text: store.location.districtName)
            BulletItem(text: store.location.timestamp.text())
        }
    }
}
