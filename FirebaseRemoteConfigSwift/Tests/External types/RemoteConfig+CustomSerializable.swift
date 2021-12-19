//
//  File.swift
//  
//
//  Created by 伊藤史 on 2021/11/23.
//

import Foundation

final class RemoteConfigCustomSerializableSpec: RemoteConfigSerializableSpec<FrogCustomSerializable> {
    var defaultValue: FrogCustomSerializable = FrogCustomSerializable(name: "default")
    var keyStore = FrogKeyStore<FrogCustomSerializable>()
    
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
