import Foundation

/// Describes the timing of instantiation.
public enum InstantiationTiming {
    case lazy
    case alwaysEager
    case eagerInDefaultApp
}

/// A protocol describing functionality provided from the Component.
public protocol ComponentLifecycleMaintainer {
    /// The associated app will be deleted, clean up any resources as they are about to be deallocated.
    func appWillBeDeleted(_ app: FirebaseApp)
}

/// A component that can be used from other Firebase SDKs.
public struct Component<T> {
    /// The protocol describing functionality provided by the component.
    public let serviceType: T.Type

    /// The timing of instantiation.
    public let instantiationTiming: InstantiationTiming

    /// A block to instantiate an instance of the component with the appropriate dependencies.
    public let creationBlock: (ComponentContainer) -> T?

    public init(_ serviceType: T.Type,
                instantiationTiming: InstantiationTiming = .lazy,
                creationBlock: @escaping (ComponentContainer) -> T?) {
        self.serviceType = serviceType
        self.instantiationTiming = instantiationTiming
        self.creationBlock = creationBlock
    }
}

// MARK: - Internal

protocol AnyComponent {
    var instantiationTiming: InstantiationTiming { get }
    func instantiate(container: ComponentContainer) -> Any?
    var serviceTypeID: ObjectIdentifier { get }
}

extension Component: AnyComponent {
    func instantiate(container: ComponentContainer) -> Any? {
        return creationBlock(container)
    }

    var serviceTypeID: ObjectIdentifier {
        return ObjectIdentifier(serviceType)
    }
}
