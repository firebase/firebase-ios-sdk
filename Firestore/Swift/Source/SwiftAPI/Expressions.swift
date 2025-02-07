//
//  Expressions.swift
//  FirebaseFirestore
//
//  Created by Hui Wu on 2/10/25.
//

import Foundation

public protocol Expr {
  var bridge: ExprBridge { get }
}

public struct Constant: Expr {
  public var bridge: ExprBridge

  var value: any Numeric
  init(value: any Numeric) {
    self.value = value
    bridge = ConstantBridge(value as! NSNumber)
  }
}

public func constant(_ number: any Numeric) -> Constant {
  return Constant(value: number)
}

public struct Field: Expr {
  public var bridge: ExprBridge

  var name: String
  init(name: String) {
    self.name = name
    bridge = FieldBridge(name)
  }
}

public func field(_ name: String) -> Field {
  return Field(name: name)
}

protocol Function: Expr {
  var name: String { get }
}

struct Eq: Function {
  var bridge: ExprBridge

  var name: String = "eq"

  private var left: Expr
  private var right: Expr

  init(_ left: Expr, _ right: Expr) {
    self.left = left
    self.right = right
    bridge = EqFunctionBridge(left: left.bridge, right: right.bridge)
  }
}

public func eq(_ left: Expr, _ right: Expr) -> Expr {
  return Eq(left, right)
}
