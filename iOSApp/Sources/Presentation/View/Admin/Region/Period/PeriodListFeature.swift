//
//  PeriodListFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2025/12/07.
//

import ComposableArchitecture
import Foundation
import Shared

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

        let festivalId: Festival.ID
        var periods: [Period]
        @Shared fileprivate var appState: AppState?

        var latests: YearlyPeriods? {
            makePeriodsStates().first
        }

        var archives: [YearlyPeriods] {
            Array(makePeriodsStates().dropFirst())
        }

        var isLoading = false
        @Presents var destination: Destination.State?
        @Presents var alert: AlertFeature.State?

        init(festivalId: Festival.ID, periods: [Period], appState: Shared<AppState?>) {
            self.festivalId = festivalId
            self.periods = periods.sorted()
            self._appState = appState
        }

        func makePeriodsStates() -> [YearlyPeriods] {
            Dictionary(grouping: periods) { $0.date.year }
                .map { year, periods in
                    YearlyPeriods(year: year, periods: periods.sorted())
                }
                .sorted { $0.year > $1.year }
        }

        var yearOptions: [Int] {
            Array(Set(periods.map(\.date.year))).sorted()
        }

        var createYear: Int {
            (makePeriodsStates().first?.year).map { $0 + 1 } ?? SimpleDate.now.year
        }

        mutating func upsert(_ period: Period) {
            periods.removeAll { $0.id == period.id }
            periods.append(period)
            periods.sort()
        }
    }

    @CasePathable
    enum Action: Equatable {
        case periodTapped(Period)
        case archiveTapped(State.YearlyPeriods)
        case periodCreateTapped
        case batchCreateTapped(Int)
        case batchCreateReceived(AppResult<[Period]>)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<AlertFeature.Action>)
    }

    @Dependency(CreatePeriodUseCaseKey.self) var createPeriodUseCase

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .periodTapped(let period):
                state.destination = .edit(.update(period, appState: state.$appState))
                return .none
            case .archiveTapped(let archive):
                state.destination = .archives(.init(
                    festivalId: state.festivalId,
                    year: archive.year,
                    periods: archive.periods,
                    appState: state.$appState
                ))
                return .none
            case .periodCreateTapped:
                state.destination = .edit(.create(state.festivalId, appState: state.$appState))
                return .none
            case .batchCreateTapped(let year):
                state.isLoading = true
                return batchEffect(state, sourceYear: year)
            case .destination(.presented(.edit(.saveReceived(.success(let period))))),
                 .destination(.presented(.archives(.destination(.presented(.edit(.saveReceived(.success(let period)))))))):
                state.upsert(period)
                state.destination = nil
                return .none
            case .destination(.presented(.edit(.deleteReceived(.success(let periodId))))),
                 .destination(.presented(.archives(.destination(.presented(.edit(.deleteReceived(.success(let periodId)))))))):
                state.periods.removeAll { $0.id == periodId }
                state.destination = nil
                return .none
            case .batchCreateReceived(.success(let periods)):
                state.isLoading = false
                for period in periods {
                    state.upsert(period)
                }
                state.alert = AlertFeature.notice("一括作成が完了しました。")
                return .none
            case .batchCreateReceived(.failure(let error)):
                state.isLoading = false
                state.alert = AlertFeature.error(error.message)
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
        .task(Action.batchCreateReceived) { [
            source = state.periods.filter { $0.date.year == sourceYear },
            createYear = state.createYear,
            appState = state.$appState
        ] in
            var createdPeriods: [Period] = []
            for period in source {
                let newPeriod = Period(
                    id: UUID().uuidString,
                    festivalId: period.festivalId,
                    title: period.title,
                    date: .from(period.date.toDate.sameWeekday(in: createYear) ?? .now),
                    start: period.start,
                    end: period.end
                )
                createdPeriods.append(try await createPeriodUseCase(newPeriod, appState: appState))
            }
            return createdPeriods
        }
    }
}

extension PeriodListFeature.Destination.State: Equatable {}
extension PeriodListFeature.Destination.Action: Equatable {}

extension PeriodListFeature.State.YearlyPeriods: Identifiable {
    var id: Int { year }

    var text: String {
        "\(String(year))年"
    }
}
