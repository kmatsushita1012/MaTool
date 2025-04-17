//
//  RouteViewerView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/07.
//

import SwiftUI
import MapKit
import ComposableArchitecture

struct RoutePublicPage: View{
    let store: StoreOf<RoutePublicPageFeature>
    
    
    var body: some View{
        ZStack {
            // 背景のMap
            Map(coordinateRegion: .constant(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(
                        latitude: 35.681236, // 東京駅
                        longitude: 139.767125 // 東京駅
                    ),
                    span: MKCoordinateSpan(
                        latitudeDelta: 0.05,
                        longitudeDelta: 0.05
                    )
                )
            ))
                .edgesIgnoringSafeArea(.all) // フルスクリーン

            // 上に重ねるUI（ZStackの上）
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        print("設定ボタンが押されました")
                    }) {
                        Image(systemName: "gear")
                            .font(.title)
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .padding()
                }

                Spacer()

                HStack {
                    Button(action: {
                        print("現在地に移動")
                    }) {
                        Label("現在地", systemImage: "location.fill")
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    }
                }
                .padding()
            }
        }
    }
}

#Preview {
    RoutePublicPage(store:
        Store(initialState:
            RoutePublicPageFeature.State(districtId: "johoku", date: SimpleDate(year: 2025, month: 10, day: 12), title: "午前中", route: RouteDetailFeature.State(), location: LocationFeature.State()),
          reducer:
                { RoutePublicPageFeature() }
         )
    )
}
