import Foundation
#if os(Linux)
import FoundationNetworking
#endif

struct EmptyResponse: Sendable, Decodable {}