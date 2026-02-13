//
//  PeriodListFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2025/12/07.
//

import ComposableArchitecture
import Shared
import Foundation
import SQLiteData

@Reducer
struct PeriodListFeature {
    
    @Reducer
    enum Destination {
        case edit(PeriodEditFeature)
        case archives(PeriodArchivesFeature)
    }
    
    @ObservableState
    struct State: Equatable {
        struct YearlyPeriods: Equatable {
            let year: Int
            let periods: [Period]
        }
        
        let festivalId: String
        
        @FetchAll var periods: [Period]
        
        var archives: [YearlyPeriods] = []
        var latests: YearlyPeriods?
        
        var isLoading = false
        @Presents var destination: Destination.State?
        @Presents var alert: Alert.State?
    }
    
    @CasePathable
    enum Action: Equatable {
        case periodTapped(Period)
        case archiveTapped(State.YearlyPeriods)
        case periodCreateTapped
        case batchCreateTapped(Int)
        case batchCreateSuccessed
        case batchCreateFailured(String)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<Alert.Action>)
    }
    
    @Dependency(PeriodDataFetcherKey.self) var dataFetcher
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .periodTapped(let period):
                state.destination = .edit(.update(period))
                return .none
            case .archiveTapped(let archive):
                state.destination = .archives(.init(festivalId: state.festivalId, year: archive.year))
                return .none
            case .periodCreateTapped:
                state.destination = .edit(.create(state.festivalId))
                return .none
            case .batchCreateTapped(let year):
                state.isLoading = true
                return batchEffect(state, sourceYear: year)
            case .destination(.presented(.edit(.saveReceived(.success(_))))),
                    .destination(.presented(.archives(.destination(.presented(.edit(.saveReceived(.success(_)))))))),
                    .destination(.presented(.edit(.deleteReceived(.success(_))))),
                    .destination(.presented(.archives(.destination(.presented(.edit(.deleteReceived(.success(_)))))))):
                state.destination = nil
                let items = state.makePeriodsStates()
                state.latests = items.first
                state.archives = .init(items.dropFirst())
                return .none
            case .batchCreateSuccessed:
                state.isLoading = false
                state.alert = Alert.notice("一括作成が完了しました。")
                let items = state.makePeriodsStates()
                state.latests = items.first
                state.archives = .init(items.dropFirst())
                return .none
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
    
    func batchEffect(_ state: State, sourceYear: Int) -> Effect<Action> {
        .run { send in
            let source: [Period] = state.periods.filter{ $0.date.year == sourceYear }
            let newPeriods = source.map{
                Period(
                    id: UUID().uuidString,
                    festivalId: $0.festivalId,
                    title: $0.title,
                    date: .from( $0.date.toDate.sameWeekday(in: state.createYear) ?? .now),
                    start: $0.start,
                    end: $0.end
                )
            }
            let result = await task {
                for period in newPeriods {
                    _ = try await dataFetcher.create(period)
                }
            }
            switch result {
            case .success:
                await send(.batchCreateSuccessed)
            case .failure(let error):
                await send(.batchCreateFailured(error.localizedDescription))
            }
        }
    }
}

extension PeriodListFeature.Destination.State: Equatable {}
extension PeriodListFeature.Destination.Action: Equatable {}

extension PeriodListFeature.State {
    init(festivalId: String) {
        self.festivalId = festivalId
        self._periods = FetchAll(Period.where{ $0.festivalId == festivalId })
        let items = makePeriodsStates()
        self.latests = items.first
        self.archives = .init(items.dropFirst())
    }
    
    func makePeriodsStates() -> [YearlyPeriods] {
        let grouped = Dictionary(grouping: periods) { $0.date.year }

        return grouped
            .map { year, periods in
                YearlyPeriods(
                    year: year,
                    periods: periods.sorted()
                )
            }
            .sorted { $0.year > $1.year }
    }
    
    var yearOptions: [Int] {
        Array(Set(periods.map(keyPath: \.date.year))).sorted()
    }
    
    var createYear: Int {
        if let latest = latests?.year {
            latest + 1
        } else {
            SimpleDate.now.year
        }
    }
}

extension PeriodListFeature.State.YearlyPeriods: Identifiable {
    var id: Int { year }
    
    var text: String {
        "\(String(year))年"
    }
}
