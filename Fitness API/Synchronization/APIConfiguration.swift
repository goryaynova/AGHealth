import Foundation

struct APIConfiguration {
    let baseURL: URL
    let keychain: KeychainManager

    init(
        baseURL: URL = URL(string: "http://100.123.202.44:8791")!,
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
