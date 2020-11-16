//
//  File.swift
//  
//
//  Created by Peter Friese on 16/11/2020.
//

import Foundation

#if canImport(FirebaseAuth)

public class FirebaseCombineAuthDummy {
  public static func sayHi(name: String) -> String {
    return "Hello, \(name)!"
  }
}

#endif
