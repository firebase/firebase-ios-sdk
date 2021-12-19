//
//  File.swift
//  
//
//  Created by 伊藤史 on 2021/11/21.
//

import Foundation
@testable import SwiftyRemoteConfig

#if canImport(UIKit) || canImport(AppKit)
#if canImport(UIKit)
    import UIKit.UIColor
    public typealias Color = UIColor
#elseif canImport(AppKit)
    import AppKit.NSColor
    public typealias Color = NSColor
#endif

extension Color: RemoteConfigSerializable {}

final class RemoteConfigColorSerializableSpec: RemoteConfigSerializableSpec<Color> {
    var defaultValue: Color = .blue
    var keyStore = FrogKeyStore<Color>()

    override class func setUp() {
        super.setupFirebase()
    }

    func testValues() {
        super.testValues(defaultValue: defaultValue, keyStore: keyStore)
    }

    func testOptionalValues() {
        super.testOptionalValues(defaultValue: defaultValue, keyStore: keyStore)
    }

    func testOptionalValuesWithoutDefaultValue() {
        super.testOptionalValuesWithoutDefaultValue(defaultValue: defaultValue, keyStore: keyStore)
    }
}
#endif
