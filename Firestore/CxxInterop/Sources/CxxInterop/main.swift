// The Swift Programming Language
// https://docs.swift.org/swift-book
// In main.swift

import CxxTest
import FirebaseFirestoreTarget

public struct CxxInterop {
    public func callCxxFunction(n: Int32) -> Int32 {
        return cxxFunction(n)
    }
}

print(CxxInterop().callCxxFunction(n: 7))
// outputs: 7
