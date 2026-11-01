import Dependencies

struct StoreRouter: Router {
    @Dependency(StoreControllerKey.self) var controller

    func body(_ app: Application) {
        app.get(path: "/advertisers/me/stores", controller.owned)
        app.post(path: "/festivals/:festivalId/stores", controller.create)
        app.get(path: "/stores/:storeId", controller.get)
        app.put(path: "/stores/:storeId", controller.put)
        app.get(path: "/festivals/:festivalId/stores", controller.publicList)
    }
}
