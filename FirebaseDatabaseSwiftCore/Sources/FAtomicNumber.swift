//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 29/10/2021.
//

import Foundation

class FAtomicNumber: NSObject {
    var number: Int = 1
    var lock: NSLock = NSLock()

    // See:
    // http://developer.apple.com/library/ios/#DOCUMENTATION/Cocoa/Conceptual/Multithreading/ThreadSafety/ThreadSafety.html#//apple_ref/doc/uid/10000057i-CH8-SW14
    // to improve, etc.

    #warning("Use swift-atomics instead? Or is this good enough?")
    func getAndIncrement() -> Int {
        lock.lock()
        defer { lock.unlock() }
        let result = number
        number += 1
        return result
    }
}

