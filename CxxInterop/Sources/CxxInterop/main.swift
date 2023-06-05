// The Swift Programming Language
// https://docs.swift.org/swift-book
// In main.swift

import CxxTest
import FirebaseFirestoreTarget
import FirestoreCore

public struct CxxInterop {
    public func callCxxFunction(n: Int32) -> Int32 {
        let sm = firebase.firestore.api.SnapshotMetadata()
        if !sm.from_cache() {
            return cxxFunction(n)
        } else {
            return cxxFunction(n + 1)
        }
    }
}

print(CxxInterop().callCxxFunction(n: 7))
// outputs: 7
