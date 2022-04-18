//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 13/04/2022.
//

import Foundation

@objc public class DatabaseTMP: NSObject {
    @objc public static var buildVersion: String {
        // TODO: Restore git hash when build moves back to git
        // XXX TODO: No DATE macro in Swift
        let date = "Apr 20 2022"
        return "\(sdkVersion)_\(date)"
    }
    @objc public static var sdkVersion: String {
        // XXX TODO: Firebase version should be a define!
        "8.7.0"
    }
}
