//
//  PeriodListFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2025/12/07.
//

import ComposableArchitecture
import Shared
import Foundation

@Reducer
struct PeriodListFeature {
    
    @Reducer
    enum Destination {
        case edit(PeriodEditFeature)
        case archives(PeriodArchivesFeature)
    }
    
    @ObservableState
    struct State: Equatable {
        let festivalId: String
        var periods: [Period]  {
            didSet {
                let periodsStates = makePeriodsStates(from: periods)
                self.latests = periodsStates.first
                self.archives = .init(periodsStates.dropFirst())
            }
        }
        var latests: PeriodsState?
        var archives: [PeriodsState]
        var isLoading = false
        @Presents var destination: Destination.State?
        @Presents var alert: Alert.State?
    }
    
    @CasePathable
    enum Action: Equatable {
        case periodTapped(Period)
        case archiveTapped(PeriodsState)
        case periodCreateTapped
        case batchCreateTapped(Int)
        case getReceived(Result<[Period], APIError>)
        case batchCreateSuccessed([Period])
        case batchCreateFailured(String)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<Alert.Action>)
    }
    
    @Dependency(\.apiRepository) var apiRepository
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .periodTapped(let period):
                state.destination = .edit(.update(period))
                return .none
            case .archiveTapped(let archive):
                state.destination = .archives(.init(festivalId: state.festivalId, year: archive.year , periods: archive.items))
                return .none
            case .periodCreateTapped:
                state.destination = .edit(.create(state.festivalId))
                return .none
            case .batchCreateTapped(let year):
                state.isLoading = true
                return batchEffect(state, year: year)
            case .destination(.presented(.edit(.saveReceived(.success(_))))),
                    .destination(.presented(.archives(.destination(.presented(.edit(.saveReceived(.success(_)))))))),
                    .destination(.presented(.edit(.deleteReceived(.success(_))))),
                    .destination(.presented(.archives(.destination(.presented(.edit(.deleteReceived(.success(_)))))))):
                state.destination = nil
                state.isLoading = true
                return getEffect(state)
            case .getReceived(.success(let periods)):
                state.periods = periods
                state.isLoading = false
                return .none
            case .getReceived(.failure(let error)):
                state.isLoading = false
                state.alert = Alert.error(error.localizedDescription)
                return .none
            case .batchCreateSuccessed(let periods):
                state.periods = periods
                state.isLoading = false
                state.alert = Alert.notice("一括作成が完了しました。")
                return getEffect(state)
            case .batchCreateFailured(let message):
                state.isLoading = false
                state.alert = Alert.error(message)
                return .none
            case .alert(.presented(_)):
                state.alert = nil
                return .none
            default:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$alert, action: \.alert)
    }
    
    func getEffect(_ state: State) -> Effect<Action> {
        .run { [state] send in
            let result = await apiRepository.getPeriodsByFestivalId(state.festivalId)
            await send(.getReceived(result))
        }
    }
    
    func batchEffect(_ state: State, year: Int) -> Effect<Action> {
        .run { send in
            guard let latests = state.latests else {
                await send(.batchCreateFailured("過去のデータが存在しません。"))
                return
            }
            let all = [latests] + state.archives
            guard let source: PeriodsState = all.first(where: { $0.year < year  }) else {
                await send(.batchCreateFailured("過去のデータが存在しません。"))
                return
            }
            let newPeriods = source.items.map{
                Period(
                    id: UUID().uuidString,
                    festivalId: $0.festivalId,
                    title: $0.title,
                    date: .from( $0.date.toDate.sameWeekday(in: year) ?? .now),
                    start: $0.start,
                    end: $0.end
                )
            }
            for period in newPeriods {
                let result = await apiRepository.postPeriod(period)
                if case let .failure(error) = result {
                    await send(.batchCreateFailured(error.localizedDescription))
                    return
                }
            }
            let result = await apiRepository.getPeriodsByFestivalId(state.festivalId)
            switch result {
            case .success(let periods):
                await send(.batchCreateSuccessed(periods))
            case .failure(let error):
                await send(.batchCreateFailured(error.localizedDescription))
            }
            
        }
    }
}

extension PeriodListFeature.Destination.State: Equatable {}
extension PeriodListFeature.Destination.Action: Equatable {}

extension PeriodListFeature.State {
    init(festivalId: String, periods: [Period]) {
        self.festivalId = festivalId
        self.periods = periods
        self.archives = []
        let periodsStates = makePeriodsStates(from: periods)
        self.latests = periodsStates.first
        self.archives = .init(periodsStates.dropFirst())
    }
    
    private func makePeriodsStates(from periods: [Period]) -> [PeriodsState] {
        let grouped = Dictionary(grouping: periods) { $0.date.year }

        return grouped
            .map { year, periods in
                PeriodsState(
                    year: year,
                    items: periods.sorted()
                )
            }
            .sorted { $0.year > $1.year }
    }
    
    var batchCreateYearOptions: [Int]? {
        if let latests, !archives.isEmpty {
            [latests.year, latests.year + 1]
        } else if let latests {
            [latests.year + 1]
        } else {
            []
        }
    }
}


struct PeriodsState: Equatable, Identifiable {
    let year: Int
    let items: [Period]
    
    var text: String {
        "\(String(year))年"
    }
    
    var id: Int {
        year
    }
}
