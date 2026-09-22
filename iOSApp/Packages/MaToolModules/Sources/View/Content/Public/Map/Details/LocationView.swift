import iOSShared
//
//  LocationView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/08/05.
//

import SwiftUI
import Shared
import SQLiteData

public struct LocationView: View {
    let entry: FloatEntry
    
    public init(_ entry: FloatEntry) {
        self.entry = entry
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16){
            BulletItem(text: "\(entry.district.name)")
            BulletItem(text: entry.floatLocation.timestamp.text())
            PublicMapBannerAdSection()
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}
