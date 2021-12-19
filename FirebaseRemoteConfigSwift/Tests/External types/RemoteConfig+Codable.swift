//
//  RemoteConfig+Codable.swift
//  
//
//  Created by 伊藤史 on 2021/11/23.
//

import Foundation
import FirebaseRemoteConfigSwift

final class RemoteConfigCodableSpec: RemoteConfigSerializableSpec<FrogCodable> {
    var defaultValue: FrogCodable = FrogCodable(name: "default")
    var keyStore = FrogKeyStore<FrogCodable>()

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
