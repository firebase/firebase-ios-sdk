//
//  File.swift
//  
//
//  Created by 伊藤史 on 2021/11/23.
//

import Foundation

final class RemoteConfigFrogSerializableSpec: RemoteConfigSerializableSpec<FrogSerializable> {
    var defaultValue: FrogSerializable = FrogSerializable(name: "default")
    var keyStore = FrogKeyStore<FrogSerializable>()
    
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
