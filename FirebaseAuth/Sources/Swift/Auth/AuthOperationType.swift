//
//  File.swift
//
//
//  Created by Morten Bek Ditlevsen on 20/01/2023.
//

import Foundation
/**
    @brief Indicates the type of operation performed for RPCs that support the operation
        parameter.
 */
@objc(FIRAuthOperationType) public enum AuthOperationType: Int {
  /** Indicates that the operation type is uspecified.
   */
  case unspecified = 0

  /** Indicates that the operation type is sign in or sign up.
   */
  case signUpOrSignIn = 1

  /** Indicates that the operation type is reauthentication.
   */
  case reauth = 2

  /** Indicates that the operation type is update.
   */
  case update = 3

  /** Indicates that the operation type is link.
   */
  case link = 4
}
