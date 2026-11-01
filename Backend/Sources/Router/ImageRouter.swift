import Dependencies

struct ImageRouter: Router {
    @Dependency(ImageUploadControllerKey.self) var controller

    func body(_ app: Application) {
        app.post(path: "/images/upload-url", controller.post)
    }
}
