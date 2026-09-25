/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
#if canImport(os.log)
  import os.log
#endif

#if os(iOS) || os(tvOS) || os(visionOS) 
import UIKit
#elseif os(watchOS)
import WatchKit
#endif

enum InstrumentationUtils {
    static func objc_getClassList() -> [AnyClass] {
        let expectedClassCount = ObjectiveC.objc_getClassList(nil, 0)
        let allClasses = UnsafeMutablePointer<AnyClass>.allocate(capacity: Int(expectedClassCount))
        let autoreleasingAllClasses = AutoreleasingUnsafeMutablePointer<AnyClass>(allClasses)
        let actualClassCount: Int32 = ObjectiveC.objc_getClassList(autoreleasingAllClasses, expectedClassCount)
        
        var classes = [AnyClass]()
        for i in 0 ..< actualClassCount {
            classes.append(allClasses[Int(i)])
        }
        allClasses.deallocate()
        return classes
    }
    
    static func objc_getSafeClassList(ignoredPrefixes: [String]? = nil) -> [AnyClass] {
        let allClasses = objc_getClassList()
        var safeClasses: [AnyClass] = []
        
        for cls in allClasses {
            let className = NSStringFromClass(cls)
            if let ignoredPrefixes = ignoredPrefixes {
                if ignoredPrefixes.contains(where: { className.hasPrefix($0) }) {
                    continue
                }
            }
            safeClasses.append(cls)
        }
        
        if #available(iOS 14, macOS 11, tvOS 14, *) {
          os_log(.info, "failed to initialize network connection status: %ld", safeClasses.count)
        }
        return safeClasses
    }
    
    static func instanceRespondsAndImplements(cls: AnyClass, selector: Selector) -> Bool {
        var implements = false
        if cls.instancesRespond(to: selector) {
            var methodCount: UInt32 = 0
            guard let methodList = class_copyMethodList(cls, &methodCount) else {
                return implements
            }
            defer { free(methodList) }
            if methodCount > 0 {
                enumerateCArray(array: methodList, count: methodCount) { _, m in
                    let sel = method_getName(m)
                    if sel == selector {
                        implements = true
                        return
                    }
                }
            }
        }
        return implements
    }
    
    private static func enumerateCArray<T>(array: UnsafePointer<T>, count: UInt32, f: (UInt32, T) -> Void) {
        var ptr = array
        for i in 0 ..< count {
            f(i, ptr.pointee)
            ptr = ptr.successor()
        }
    }
}
