struct ImageRouter: Router {
    func body(_ app: Application) {
        app.post(path: "/images/upload-url", ImageUploadController().post)
    }
}
