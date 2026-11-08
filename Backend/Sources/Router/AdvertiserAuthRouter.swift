import Dependencies

struct AdvertiserAuthRouter: Router {
    @Dependency(AdvertiserAuthControllerKey.self) var controller

    func body(_ app: Application) {
        app.post(path: "/advertisers/signup", controller.signUp)
        app.post(path: "/advertisers/confirm-signup", controller.confirmSignUp)
    }
}
