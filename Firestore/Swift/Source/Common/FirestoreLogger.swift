//
//  File.swift
//  
//
//  Created by Aashish Patil on 5/29/23.
//

import Foundation
import OSLog

/// Base FirestoreLogger class
/// Logging categories can be created by extending FirestoreLogger and defining a static FirestoreLogger var with your category
/// 
/// ```
/// extension FirestoreLogger {
///  static var myCategory = FirestoreLogger(category: "myCategory")
/// }
/// ```
///
/// To use your extension, call
/// ```
/// FirestoreLogger.myCategory.log(msg, vars)
/// ```
/// See ReferenceableObject.swift for the FirestoreLogger extension for an example

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
class FirestoreLogger: OSLog {

  private let firestoreSubsystem = "com.google.firebase.firestore"

  init(category: String) {
    super.init(subsystem: firestoreSubsystem, category: category)
  }

  func debug(_ message: StaticString, _ args: CVarArg...) {
    os_log(message, log: self, type: .debug, args)
  }

  func info(_ message: StaticString, _ args: CVarArg...) {
    os_log(message, log: self, type: .info, args)
  }

  func log(_ message: StaticString, _ args: CVarArg...) {
    os_log(message, log: self, type: .default, args)
  }

  func error(_ message: StaticString, _ args: CVarArg) {
    os_log(message, log: self, type: .error, args)
  }

  func fault(_ message: StaticString, _ args: CVarArg) {
    os_log(message, log: self, type: .fault, args)
  }

}
