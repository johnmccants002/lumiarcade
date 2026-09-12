import Foundation

struct AppInvocation: Equatable {
    let url: URL?

    init(url: URL? = nil) {
        self.url = url
    }
}
