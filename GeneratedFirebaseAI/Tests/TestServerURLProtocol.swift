import GeneratedFirebaseAI
import FirebaseCore
import Foundation

/// A URLProtocol that intercepts Firebase requests and redirects them
/// to the local test-server instances based on host mapping.
class TestServerURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var currentTestName: String?

    nonisolated(unsafe) static var hostPortMapping: [String: Int] = [:]

    override class func canInit(with request: URLRequest) -> Bool {
        guard let host = request.url?.host else { return false }
        return hostPortMapping.keys.contains(host)
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let url = request.url, let redirectedURL = redirectURL(for: url) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        var redirectedRequest = request
        redirectedRequest.url = redirectedURL

        if let testName = TestServerURLProtocol.currentTestName {
            redirectedRequest.setValue(testName, forHTTPHeaderField: "Test-Name")
        }

        let task = URLSession.shared.dataTask(with: redirectedRequest) { [weak self] data, response, error in
            guard let self = self else { return }
            if let error = error {
                self.client?.urlProtocol(self, didFailWithError: error)
                return
            }
            if let response = response {
                self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }
            if let data = data {
                self.client?.urlProtocol(self, didLoad: data)
            }
            self.client?.urlProtocolDidFinishLoading(self)
        }
        task.resume()
    }

    override func stopLoading() {}

    private func redirectURL(for url: URL) -> URL? {
        guard let host = url.host, let port = TestServerURLProtocol.hostPortMapping[host] else {
            return nil
        }

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.scheme = "http"
        components?.host = "localhost"
        components?.port = port

        return components?.url
    }
}