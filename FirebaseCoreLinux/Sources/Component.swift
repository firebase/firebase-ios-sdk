// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

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
