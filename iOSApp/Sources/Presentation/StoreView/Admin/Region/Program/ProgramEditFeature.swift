//
//  ProgramEditFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2025/12/07.
//

import ComposableArchitecture
import Shared

@Reducer
struct ProgramEditFeature {    
    @Reducer
    enum Destination {
        case period(PeriodEditFeature)
    }
    
    @ObservableState
    struct State: Equatable {
        var mode: Mode = .update
        var program: Program
        var year: Int {
            didSet {
                let old = program
                program = Program(festivalId: old.festivalId, year: year, periods: old.periods)
            }
        }
        var isLoading: Bool = false
        @Presents var destination: Destination.State?
        @Presents var alert: Alert.State?
    }
    
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case saveTapped
        case deleteTapped
        case cancelTapped
        case periodTapped(Period)
        case periodCreateTapped
        case saveReceived(Result<Program, APIError>)
        case deleteReceived(Result<Empty, APIError>)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<Alert.Action>)
    }
    
    @Dependency(\.dismiss) var dismiss
    @Dependency(\.apiRepository) var apiRepository
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .saveTapped:
                state.isLoading = true
                return saveEffect(state)
            case .deleteTapped:
                state.isLoading = true
                return deleteEffect(state)
            case .cancelTapped:
                return .run{ _ in
                    await dismiss()
                }
            case .periodTapped(let period):
                state.destination = .period(.init(period: period))
                return .none
            case .periodCreateTapped:
                state.destination = .period(.init(period: .init(date: .init(year: state.year, month: 1, day: 1))))
                return .none
            case .saveReceived(.success(_)), .deleteReceived(.success(_)):
                state.isLoading = false
                return .none
            case .saveReceived(.failure(let error)), .deleteReceived(.failure(let error)):
                state.alert = Alert.error(error.localizedDescription)
                state.isLoading = false
                return .none
            case .destination(.presented(.period(.doneTapped))):
                guard let target = state.destination?.period?.period else { return .none }
                state.program.periods.upsert(target)
                state.destination = nil
                return .none
            case .destination(.presented(.period(.deleteTapped))):
                guard let target = state.destination?.period?.period else { return .none }
                state.program.periods.removeAll(where: { $0.id == target.id })
                state.destination = nil
                return .none
            case .alert(_):
                state.alert = nil
                return .none
            default:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$alert, action: \.alert)
    }
    
    func saveEffect(_ state: State) -> Effect<Action>{
        .run{ [state] send in
            let result = await {
                switch state.mode{
                case .create:
                    await apiRepository.postProgram(state.program)
                case .update:
                    await apiRepository.putProgram(state.program)
                }
            }()
            await send(.saveReceived(result))
        }
    }
    
    func deleteEffect(_ state: State) -> Effect<Action>{
        .run{ [state] send in
            let result = await apiRepository.deleteProgram(state.program.festivalId, state.program.year)
            await send(.deleteReceived(result))
        }
    }
}

extension ProgramEditFeature.Destination.State: Equatable {}
extension ProgramEditFeature.Destination.Action: Equatable {}

extension ProgramEditFeature.State {
    var isYearEditable: Bool {
        mode == .create
    }
}

extension ProgramEditFeature.State {
    static func create(festivalId: String) -> Self {
        let year = SimpleDate.now.year
        let program = Program(festivalId: festivalId, year: year, periods: [])
        return .init(mode: .create, program: program, year: year)
    }
    
    static func update(program: Program) -> Self {
        return .init(mode: .update, program: program, year: program.year)
    }
}
