import ComposableArchitecture
import Foundation
import Shared

@Reducer
struct EditionListFeature {
    @Reducer
    enum Destination {
        case edit(EditionEditFeature)
    }

    @ObservableState
    struct State: Equatable {
        let festivalID: Festival.ID
        @Shared fileprivate var appState: AppState?
        var editions: [Edition] = []
        var activeEditionID: Edition.ID?
        var isLoading = false
        var isCreating = false
        var hasLoaded = false
        var hasLoadError = false
        var isCreationAlertPresented = false
        var newEditionYearText = ""
        @Presents var destination: Destination.State?
        @Presents var alert: AlertFeature.State?

        var nextEditionYear: Int {
            editions.map(\.year).max().map { $0 + 1 }
                ?? Calendar.current.component(.year, from: .now)
        }

        init(festivalID: Festival.ID, appState: Shared<AppState?> = Shared(value: nil)) {
            self.festivalID = festivalID
            self._appState = appState
        }
    }

    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case listReceived(AppResult<EditionListResponse>)
        case editionTapped(Edition)
        case addEditionTapped
        case createConfirmed
        case createCancelled
        case autoCreateTapped
        case creationReceived(AppResult<EditionPack>)
        case autoCreationReceived(AppResult<EditionPack>)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<AlertFeature.Action>)
    }

    @Dependency(EditionDataFetcherKey.self) private var editionDataFetcher
    @Dependency(AutoCreateEditionUseCaseKey.self) private var autoCreateEditionUseCase

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .onAppear:
                guard !state.hasLoaded else { return .none }
                state.isLoading = true
                state.hasLoadError = false
                return listEffect(festivalID: state.festivalID)
            case .listReceived(.success(let response)):
                state.isLoading = false
                state.hasLoaded = true
                state.hasLoadError = false
                state.editions = response.editions.sorted { $0.year > $1.year }
                state.activeEditionID = response.activeEditionId
                if let destination = state.destination, case var .edit(editState) = destination {
                    editState.activeEditionID = response.activeEditionId
                    state.destination = .edit(editState)
                }
                return .none
            case .listReceived(.failure(let error)):
                state.isLoading = false
                state.hasLoadError = true
                state.alert = AlertFeature.error("年度一覧を取得できませんでした。\n\(error.message)")
                return .none
            case .editionTapped(let edition):
                state.destination = .edit(EditionEditFeature.State(
                    festivalID: state.festivalID,
                    edition: edition,
                    activeEditionID: state.activeEditionID,
                    appState: state.$appState
                ))
                return .none
            case .addEditionTapped:
                guard !state.isLoading, !state.isCreating else { return .none }
                state.newEditionYearText = String(state.nextEditionYear)
                state.isCreationAlertPresented = true
                return .none
            case .createConfirmed:
                guard !state.isLoading, !state.isCreating,
                      let year = validateNewEditionYear(&state) else { return .none }
                state.isCreationAlertPresented = false
                state.isCreating = true
                return .task(Action.creationReceived) { [festivalID = state.festivalID] in
                    try await editionDataFetcher.create(festivalID: festivalID, year: year)
                }
            case .createCancelled:
                state.isCreationAlertPresented = false
                return .none
            case .autoCreateTapped:
                guard !state.isLoading, !state.isCreating,
                      let year = validateNewEditionYear(&state) else { return .none }
                state.isCreationAlertPresented = false
                guard let sourceEdition = state.editions.first(where: { $0.id == state.activeEditionID })
                    ?? state.editions.first else {
                    state.alert = AlertFeature.error("コピー元となる年度がありません。")
                    return .none
                }
                state.isCreating = true
                return .task(Action.autoCreationReceived) {
                    try await autoCreateEditionUseCase(sourceEdition: sourceEdition, targetYear: year)
                }
            case .creationReceived(.success(let pack)):
                state.isCreating = false
                state.editions.removeAll { $0.id == pack.edition.id || $0.year == pack.edition.year }
                state.editions.append(pack.edition)
                state.editions.sort { $0.year > $1.year }
                state.destination = .edit(EditionEditFeature.State(
                    festivalID: state.festivalID,
                    pack: pack,
                    activeEditionID: state.activeEditionID,
                    appState: state.$appState
                ))
                return .none
            case .creationReceived(.failure(let error)):
                state.isCreating = false
                state.alert = AlertFeature.error("年度を作成できませんでした。\n\(error.message)")
                return .none
            case .autoCreationReceived(.success(let pack)):
                state.isCreating = false
                state.editions.removeAll { $0.id == pack.edition.id || $0.year == pack.edition.year }
                state.editions.append(pack.edition)
                state.editions.sort { $0.year > $1.year }
                return .none
            case .autoCreationReceived(.failure(let error)):
                state.isCreating = false
                state.alert = AlertFeature.error("日程を自動作成できませんでした。\n\(error.message)")
                return .none
            case .destination(.presented(.edit(.saveReceived(.success)))):
                state.isLoading = true
                return listEffect(festivalID: state.festivalID)
            case .destination(.presented(.edit(.activationReceived(.success(let result))))):
                state.activeEditionID = result.activeEdition.editionId
                state.isLoading = true
                return listEffect(festivalID: state.festivalID)
            case .destination(.presented(.edit(.activationReceived(.failure)))):
                state.isLoading = true
                return listEffect(festivalID: state.festivalID)
            case .alert(.presented):
                state.alert = nil
                return .none
            default:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$alert, action: \.alert)
    }

    private func listEffect(festivalID: Festival.ID) -> Effect<Action> {
        .task(Action.listReceived) {
            try await editionDataFetcher.fetchList(festivalID: festivalID)
        }
    }

    private func validateNewEditionYear(_ state: inout State) -> Int? {
        let yearText = state.newEditionYearText.trimmingCharacters(in: .whitespacesAndNewlines)
        let year = yearText.isEmpty ? state.nextEditionYear : Int(yearText)
        guard let year, year > 0 else {
            state.isCreationAlertPresented = false
            state.alert = AlertFeature.error("年度は1以上の整数で入力してください。")
            return nil
        }
        guard !state.editions.contains(where: { $0.year == year }) else {
            state.isCreationAlertPresented = false
            state.alert = AlertFeature.error("\(String(year))年度はすでに登録されています。")
            return nil
        }
        return year
    }
}

extension EditionListFeature.Destination.State: Equatable {}
extension EditionListFeature.Destination.Action: Equatable {}
