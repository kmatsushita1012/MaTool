import Dependencies

struct AdvertisementRouter: Router {
    @Dependency(AdvertisementControllerKey.self) var controller

    func body(_ app: Application) {
        app.get(path: "/festivals/:festivalId/advertisements/next", controller.next)
        app.post(path: "/advertisements/impressions", controller.impression)
        app.post(path: "/advertisements/reports", controller.report)
    }
}
