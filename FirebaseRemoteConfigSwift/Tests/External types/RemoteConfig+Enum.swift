//
//  RemoteConfig+Enum.swift
//  
//
//  Created by 伊藤史 on 2021/11/23.
//

import Foundation
import FirebaseRemoteConfigSwift

final class RemoteConfigBestFroggiesEnumSerializableSpec: RemoteConfigSerializableSpec<BestFroggiesEnum> {
    var defaultValue: BestFroggiesEnum = .Dandy
    var keyStore = FrogKeyStore<BestFroggiesEnum>()
    
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
