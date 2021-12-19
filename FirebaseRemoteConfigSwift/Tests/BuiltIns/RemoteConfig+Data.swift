//
//  File.swift
//  
//
//  Created by 伊藤史 on 2021/11/21.
//

import Foundation

final class RemoteConfigDataSpec: RemoteConfigSerializableSpec<Data> {
    var defaultValue: Data = Data()
    var keyStore = FrogKeyStore<Data>()
    
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
