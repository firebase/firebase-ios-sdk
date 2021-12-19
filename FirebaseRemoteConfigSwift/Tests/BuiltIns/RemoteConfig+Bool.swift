//
//  RemoteConfig+Bool.swift
//  
//
//  Created by 伊藤史 on 2021/11/18.
//

import Foundation

final class RemoteConfigBoolSpec: RemoteConfigSerializableSpec<Bool> {
    var defaultValue: Bool = true
    var keyStore = FrogKeyStore<Bool>()

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
