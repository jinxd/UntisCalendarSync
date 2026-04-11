import Foundation

struct UntisCredentials {
    let server: String
    let username: String
    let password: String

    var baseURL: URL {
        URL(string: "https://\(server)")!
    }
}
