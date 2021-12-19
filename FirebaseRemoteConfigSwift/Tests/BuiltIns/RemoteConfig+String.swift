//
//  File.swift
//  
//
//  Created by 伊藤史 on 2021/11/21.
//

import Foundation

final class RemoteConfigStringSpec: RemoteConfigSerializableSpec<String> {
    var defaultValue: String = "Firebase"
    var keyStore = FrogKeyStore<String>()
    
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
