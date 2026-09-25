import Foundation

struct APIConfiguration {
    let baseURL: URL
    let keychain: KeychainManager

    init(
        baseURL: URL = URL(string: "https://health.annagrv17.ru")!,
        keychain: KeychainManager = KeychainManager()
    ) {
        self.baseURL = baseURL
        self.keychain = keychain
    }

    func makeAPIClient() throws -> APIClient {
        guard let token = try keychain.getToken(),
              !token.isEmpty else {
            throw APIConfigurationError.tokenNotConfigured
        }

        return APIClient(
            baseURL: baseURL,
            token: token
        )
    }
}

enum APIConfigurationError: Error {
    case tokenNotConfigured
}
