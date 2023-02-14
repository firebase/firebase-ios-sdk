//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 13/02/2023.
//

import Foundation

internal let kAuthGlobalWorkQueue = DispatchQueue(label: "com.google.firebase.auth.globalWorkQueue")

// TODO: Hack to allow Obj-C to get a hold of this

@objc public class FIRAuthGlobalWorkQueueWrapper: NSObject {
    @objc public static var queue: DispatchQueue = kAuthGlobalWorkQueue
}
