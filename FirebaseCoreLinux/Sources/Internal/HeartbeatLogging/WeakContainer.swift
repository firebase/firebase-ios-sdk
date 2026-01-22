import Foundation

/// A structure used to weakly box reference types.
struct WeakContainer<Object: AnyObject> {
  weak var object: Object?
}

// Sendable conformance needs to be unchecked if we can't guarantee Object is Sendable in a way Swift likes,
// but here it says `where Object: Sendable`.
extension WeakContainer: Sendable where Object: Sendable {}
