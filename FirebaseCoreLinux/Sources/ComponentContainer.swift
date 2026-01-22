import Foundation

/// A container that holds different components.
public protocol ComponentContainer {
    /// A reference to the app that an instance of the container belongs to.
    var app: FirebaseApp { get }

    /// Fetch an instance for the given service type.
    func instance<T>(for serviceType: T.Type) -> T?
}
