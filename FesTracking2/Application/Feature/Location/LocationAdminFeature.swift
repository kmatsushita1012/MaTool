//
//  LocationFeature.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/05.
//

import ComposableArchitecture
import CoreLocation

@Reducer
struct LocationAdminFeature{
    
    @ObservableState
    struct State:Equatable{
        let id: String
        var location: Location?
        var isTracking: Bool = false
        var isLoading: Bool = false
        var logs: [String] = []
    }
    
    enum Action: BindableAction{
        case onAppear
        case binding(BindingAction<State>)
        case toggleChanged(Bool)
        case updated(AsyncValue<CLLocation>)
        case getReceived(Result<Location?,ApiError>)
        case postReceived(Result<String,ApiError>)
        
    }
    
    @Dependency(\.apiClient) var apiClient
    @Dependency(\.locationClient) var locationClient
    
    var body: some ReducerOf<LocationAdminFeature> {
        BindingReducer()
        Reduce{state, action in
            switch action{
            case .onAppear:
                return .run{ [id = state.id] send in
                    let item = await self.apiClient.getLocation(id)
                    await send(.getReceived(item))
                }
            case .binding:
                return .none
            case .toggleChanged(let value):
                state.isTracking = value
                if(value){
                    print("true")
                    return locationClient.startTracking()
                }else{
                    print("false")
                    locationClient.stopTracking()
                    return .none
                }
                return .none
            case .updated(.success(let cllocation)):
                print("success \(cllocation)")
                let coordinate = Coordinate(latitude: cllocation.coordinate.latitude, longitude: cllocation.coordinate.longitude)
                let location = Location(districtId: state.id, coordinate: coordinate, time: DateTime.now)
                return .run {  send in
                    let result = await apiClient.postLocation(location, "")
                    await send(.postReceived(result))
                }
            case .updated(.loading):
                print("loading ")
                return .none
            case .updated(.failure(let error)):
                print("failure \(error)")
                let date = DateTime.now.text()
                state.logs.append("\(date) 取得失敗 ")
                return .none
            case .getReceived(.success(let value)):
                print(value)
                state.location = value
                return .none
            case .getReceived(.failure(_)):
                return .none
            case .postReceived(.success(let message)):
                let date = DateTime.now.text()
                state.logs.append("\(date) 送信成功")
                return .none
            case .postReceived(.failure(let error)):
                let date = DateTime.now.text()
                state.logs.append("\(date) 送信失敗 ")
                return .none
            }
            
        }
    }
    
}
