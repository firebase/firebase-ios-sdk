//
//  SwiftCppAPI.swift
//  Firebase
//
//  Created by Cheryl Lin on 2024-10-22.
//

import FirebaseFirestoreCpp

public class SwiftCppWrapper {
  public init(_ value: String) {
    _ = UsedBySwift(std.string(value))
  }
}
