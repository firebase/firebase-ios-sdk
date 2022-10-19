//
//  ShadowDate.swift
//  Pods
//
//  Created by Leo Zhan on 2022-10-17.
//

import Foundation

// A paused Date that can only be advanced through functions
class MockDate {
  private var date = Date()
  
  func advance(by timeInterval: TimeInterval) {
    date = date.addingTimeInterval(timeInterval)
  }
  
  func getDate() -> Date {
    return date
  }
}
