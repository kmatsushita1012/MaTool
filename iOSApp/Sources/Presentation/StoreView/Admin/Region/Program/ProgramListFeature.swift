//
//  ProgramListFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2025/12/07.
//

import ComposableArchitecture
import Shared

@Reducer
struct ProgramListFeature {
    
    @Reducer
    enum Destination {
        case edit(ProgramEditFeature)
    }
    
    @ObservableState
    struct State: Equatable {
        let festivalId: String
        var programs: [Program]
        @Presents var destination: Destination.State?
        @Presents var alert: Alert.State?
    }
    
    @CasePathable
    enum Action: Equatable {
        case programTapped(Program)
        case programCreateTapped
        case getReceived(Result<[Program], APIError>)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<Alert.Action>)
    }
    
    @Dependency(\.apiRepository) var apiRepository
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .programTapped(let program):
                state.destination = .edit(.update(program: program))
                return .none
            case .programCreateTapped:
                state.destination = .edit(.create(festivalId: state.festivalId))
                return .none
            case .destination(.presented(.edit(.saveReceived(.success(_))))),
                    .destination(.presented(.edit(.deleteReceived(.success(_))))):
                state.destination = nil
                return getEffect(state)
            case .getReceived(.success(let programs)):
                state.programs = programs
                return .none
            case .getReceived(.failure(let error)):
                state.alert = Alert.error(error.localizedDescription)
                return .none
            case .alert(.presented(_)):
                state.alert = nil
                return .none
            default:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
    
    func getEffect(_ state: State) -> Effect<Action> {
        .run { [state] send in
            let result = await apiRepository.getPrograms(state.festivalId)
            await send(.getReceived(result))
        }
    }
}

extension ProgramListFeature.Destination.State: Equatable {}
extension ProgramListFeature.Destination.Action: Equatable {}

extension ProgramListFeature.State {
    var latest: Program? {
        programs.first
    }
    
    var archives: [Program] {
        .init(programs.dropFirst())
    }
    
    var shouldShowArchives: Bool {
        programs.count > 1
    }
}
