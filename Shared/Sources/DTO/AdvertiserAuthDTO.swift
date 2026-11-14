public struct AdvertiserSignUpRequest: DTO {
    public let email: String
    public let password: String

    public init(email: String, password: String) {
        self.email = email
        self.password = password
    }
}

public struct AdvertiserConfirmSignUpRequest: DTO {
    public let email: String
    public let confirmationCode: String

    public init(email: String, confirmationCode: String) {
        self.email = email
        self.confirmationCode = confirmationCode
    }
}
