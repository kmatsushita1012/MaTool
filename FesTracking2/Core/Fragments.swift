//
//  Fragments.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/18.
//

//
//import CoreLocation
//import Combine
//import ComposableArchitecture
//
//final class LocationManagerDelegate: NSObject, CLLocationManagerDelegate {
//    var subject = PassthroughSubject<CLLocation, Never>()
//
//    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
//        if let location = locations.last {
//            subject.send(location)
//        }
//    }
//
//    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
//        print("Location error: \(error.localizedDescription)")
//        if let clError = error as? CLError {
//            switch clError.code {
//            case .denied:
//                print("位置情報が拒否されました。")
//            case .locationUnknown:
//                print("位置情報が不明です。")
//            default:
//                print("位置情報の取得に失敗しました: \(clError.localizedDescription)")
//            }
//        }
//    }
//}
//
//extension LocationClient {
//    static func live(
//        actionBuilder: @escaping (CLLocation) -> Action,
//        interval: TimeInterval // 任意の秒数を受け取る
//    ) -> LocationClient {
//        let manager = CLLocationManager()
//        let delegate = LocationManagerDelegate()
//        var timer: Cancellable?
//        manager.delegate = delegate
//        manager.requestWhenInUseAuthorization()
//        manager.requestAlwaysAuthorization()
//        manager.allowsBackgroundLocationUpdates = true
//
//        return LocationClient(
//            startTracking: {
//                // 最初の位置情報リクエスト
//                manager.startUpdatingLocation()
//                // 最初に位置情報をリクエスト
//                DispatchQueue.main.async {
//                    manager.requestLocation()
//                }
//
//                // タイマーで定期的に位置情報をリクエスト
//                timer = Timer.publish(every: interval, on: .main, in: .common)
//                    .autoconnect()
//                    .sink { _ in
//                        print("Timer triggered - requesting location update")
//                        DispatchQueue.main.async {
//                            manager.requestLocation() // 定期的に位置情報をリクエスト
//                        }
//                    }
//
//                return Effect<Action>.publisher {
//                    delegate.subject
//                        .map(actionBuilder)
//                        .eraseToAnyPublisher()
//                }
//            },
//            stopTracking: {
//                manager.stopUpdatingLocation()
//                timer?.cancel()
//                timer = nil
//            }
//        )
//    }
//}
