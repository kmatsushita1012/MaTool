import Dependencies

struct PurchaseRouter: Router {
    @Dependency(PurchaseControllerKey.self) var controller

    func body(_ app: Application) {
        app.get(path: "/stores/:storeId/credits", controller.credits)
        app.post(path: "/stores/:storeId/purchases", controller.claim)
        app.get(path: "/stores/:storeId/purchases", controller.history)
        app.post(path: "/app-store/notifications", controller.notification)
    }
}
