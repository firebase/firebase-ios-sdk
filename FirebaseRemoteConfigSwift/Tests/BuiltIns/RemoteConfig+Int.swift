//
//  RemoteConfig+Int.swift
//  
//
//  Created by 伊藤史 on 2021/11/21.
//

import Foundation
import FirebaseRemoteConfigSwift

final class RemoteConfigIntSpec: RemoteConfigSerializableSpec<Int> {
    var defaultValue: Int = 1
    var keyStore = FrogKeyStore<Int>()
    
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
