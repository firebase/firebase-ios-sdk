//
//  File.swift
//  
//
//  Created by 伊藤史 on 2021/11/21.
//

import Foundation

final class RemoteConfigDoubleSpec: RemoteConfigSerializableSpec<Double> {
    var defaultValue: Double = 1.0
    var keyStore = FrogKeyStore<Double>()

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
