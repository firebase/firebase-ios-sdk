//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 13/02/2023.
//

import Foundation

public typealias FIRAuthSerialTaskCompletionBlock = () -> Void
public typealias FIRAuthSerialTask = (_ complete: @escaping FIRAuthSerialTaskCompletionBlock) -> Void

@objc(FIRAuthSerialTaskQueue) public class AuthSerialTaskQueue: NSObject {
    private let dispatchQueue: DispatchQueue
    
    @objc public override init() {
        self.dispatchQueue = DispatchQueue(label: "com.google.firebase.auth.serialTaskQueue", target: kAuthGlobalWorkQueue)
        super.init()
    }
    
    @objc public func enqueueTask(_ task: @escaping FIRAuthSerialTask) {
        dispatchQueue.async {
            self.dispatchQueue.suspend()
            task {
                self.dispatchQueue.resume()
            }
        }
    }
}
