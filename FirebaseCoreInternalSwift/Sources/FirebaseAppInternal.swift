// Copyright 2022 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import FirebaseCore
import ObjectiveC

public extension FirebaseApp {
  /// A flag indicating if this is the default app (has the default app name). Redirects to the
  /// Obj-C property of the same name.
  var isDefaultApp: Bool {
    // First two arguments are the class (FirebaseApp) and the selector name.
    typealias VoidBoolFunc = @convention(c) (AnyObject, Selector) -> Bool
    let sel = NSSelectorFromString("isDefaultApp")
    let isDefaultAppFunc = generatePrivateFunc(sel, from: self, type: VoidBoolFunc.self)
    return isDefaultAppFunc(self, sel)
  }

  /// Checks if the default app is configured without trying to configure it. Redirects to the Obj-C
  /// method of the same name.
  static var isDefaultAppConfigured: Bool {
    // First two arguments are the class (FirebaseApp) and the selector name.
    typealias VoidBoolFunc = @convention(c) (AnyClass, Selector) -> Bool
    let sel = NSSelectorFromString("isDefaultAppConfigured")
    let isDefaultAppConfigured = generatePrivateClassFunc(sel, from: self, type: VoidBoolFunc.self)
    return isDefaultAppConfigured(self, sel)
  }

  /// Create a Firebase app for test purposes. Calls an internal Obj-C initializer. Visible only
  /// with `@testable import` due to its internal naming.
  internal static func initializedApp(name: String, options: FirebaseOptions) -> FirebaseApp {
    // Call `alloc` first to allocate memory for our new instance. The first two arguments are
    // the class (FirebaseApp) and the selector name.
    typealias AllocFunc = @convention(c) (AnyClass, Selector) -> FirebaseApp
    let allocSel = NSSelectorFromString("alloc")
    let allocFunc = generatePrivateClassFunc(allocSel, from: self, type: AllocFunc.self)
    let allocated: FirebaseApp = allocFunc(self, allocSel)

    // First two arguments are the object and the selector name.
    typealias AppInitFunc = @convention(c) (AnyObject, Selector, NSString, FirebaseOptions)
      -> FirebaseApp
    let initSel = NSSelectorFromString("initInstanceWithName:options:")
    let appInitFunc = generatePrivateFunc(initSel, from: allocated, type: AppInitFunc.self)
    return appInitFunc(allocated, initSel, NSString(string: name), options)
  }
}

/// Fetches a class function of the provided type using `NSStringFromSelector` and the given class.
/// This may crash if the selector doesn't exist, so use at your own risk.
private func generatePrivateFunc<T: NSObject, U>(_ selector: Selector,
                                                 from instance: T,
                                                 type funcType: U.Type) -> U {
  guard instance.responds(to: selector) else {
    fatalError("""
    Firebase tried to get a method named \(selector) from an instance of \(type(of: instance)) but
    it doesn't exist. It may have been changed recently. Please file an issue in the
    firebase-ios-sdk repo if you see this error, and mention the Swift products that you're using
    along with this message. Sorry about that!
    https://github.com/firebase/firebase-ios-sdk/issues/new/choose
    """)
  }
  let methodImp = instance.method(for: selector)
  return unsafeBitCast(methodImp, to: funcType)
}

/// Fetches a class function of the provided type using `NSStringFromSelector` and the given class.
/// This may crash if the selector doesn't exist, so use at your own risk.
private func generatePrivateClassFunc<T: NSObject, U>(_ selector: Selector,
                                                      from klass: T.Type,
                                                      type: U.Type) -> U {
  guard klass.responds(to: selector) else {
    fatalError("""
    Firebase tried to get a method named \(selector) from a class named \(klass) but it doesn't
    exist. It may have been changed recently. Please file an issue in the firebase-ios-sdk repo
    if you see this error, and mention the Swift products that you're using along with this
    message. Sorry about that!
    https://github.com/firebase/firebase-ios-sdk/issues/new/choose
    """)
  }
  let methodImp = klass.method(for: selector)
  return unsafeBitCast(methodImp, to: type)
}
