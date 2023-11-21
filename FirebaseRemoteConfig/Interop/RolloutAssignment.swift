//
//  File.swift
//
//
//  Created by Themis Wang on 2023-11-16.
//

import Foundation

@objc(FIRRolloutAssignment)
public class RolloutAssignment: NSObject {
  @objc public var rolloutId: String
  @objc public var variantId: String
  @objc public var templateVersion: String
  @objc public var parameterKey: String
  @objc public var parameterValue: String

  public init(rolloutId: String, variantId: String, templateVersion: String, parameterKey: String,
              parameterValue: String) {
    self.rolloutId = rolloutId
    self.variantId = variantId
    self.templateVersion = templateVersion
    self.parameterKey = parameterKey
    self.parameterValue = parameterValue
    super.init()
  }
}

@objc(FIRRolloutsState)
public class RolloutsState: NSObject {
  @objc public var assignments: Set<RolloutAssignment> = Set()

  public init(assignmentList: [RolloutAssignment]) {
    for assignment in assignmentList {
      assignments.insert(assignment)
    }
    super.init()
  }
}
