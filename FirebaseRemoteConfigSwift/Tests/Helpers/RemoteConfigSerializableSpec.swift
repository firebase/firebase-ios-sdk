//
//  RemoteConfigSerializableSpec.swift
//  
//
//  Created by 伊藤史 on 2021/11/06.
//

import Foundation
import XCTest
@testable import FirebaseRemoteConfigSwift
import FirebaseRemoteConfig
import FirebaseCore

class RemoteConfigSerializableSpec<Serializable: RemoteConfigSerializable & Equatable>: XCTestCase {
}

extension RemoteConfigSerializableSpec where Serializable.T: Equatable, Serializable.T == Serializable, Serializable.ArrayBridge.T == [Serializable.T] {

    static func setupFirebase() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure(options: FrogFirebaseConfig.firebaseOptions)
        }
    }

    func testValues(defaultValue: Serializable.T, keyStore: FrogKeyStore<Serializable>) {
        given(String(describing: Serializable.self)) { _ in
            when("key-default value") { _ in
                var config: RemoteConfigAdapter<FrogKeyStore<Serializable>>!
                let remoteConfig = RemoteConfig.remoteConfig()
                config = RemoteConfigAdapter(remoteConfig: remoteConfig,
                                                   keyStore: keyStore)

                then("create a key") { _ in
                    let key = RemoteConfigKey<Serializable>("test", defaultValue: defaultValue)
                    XCTAssert(key._key == "test")
                    XCTAssert(key.defaultValue == defaultValue)
                }

                then("create an array key") { _ in
                    let key = RemoteConfigKey<[Serializable]>("test", defaultValue: [defaultValue])
                    XCTAssert(key._key == "test")
                    XCTAssert(key.defaultValue == [defaultValue])
                }

                then("get a default value") { _ in
                    let key = RemoteConfigKey<Serializable>("test", defaultValue: defaultValue)
                    XCTAssert(config[key] == defaultValue)
                }

                #if swift(>=5.1)
                then("get a default value with dynamicMemberLookup") { _ in
                    keyStore.testValue = RemoteConfigKey<Serializable>("test", defaultValue: defaultValue)
                    XCTAssert(config.testValue == defaultValue)
                }
                #endif

                then("get a default array value") { _ in
                    let key = RemoteConfigKey<[Serializable]>("test", defaultValue: [defaultValue])
                    XCTAssert(config[key] == [defaultValue])
                }

                #if swift(>=5.1)
                then("get a default array value with dynamicMemberLookup") { _ in
                    keyStore.testArray = RemoteConfigKey<[Serializable]>("test", defaultValue: [defaultValue])
                    XCTAssert(config.testArray == [defaultValue])
                }
                #endif
            }
        }
    }
    
    func testOptionalValues(defaultValue: Serializable.T, keyStore: FrogKeyStore<Serializable>) {
        given(String(describing: Serializable.self)) { _ in
            when("key-default optional value") { _ in
                var config: RemoteConfigAdapter<FrogKeyStore<Serializable>>!
                let remoteConfig = RemoteConfig.remoteConfig()
                config = RemoteConfigAdapter(remoteConfig: remoteConfig,
                                                   keyStore: keyStore)

                then("create a key") { _ in
                    let key = RemoteConfigKey<Serializable?>("test", defaultValue: defaultValue)
                    XCTAssert(key._key == "test")
                    XCTAssert(key.defaultValue == defaultValue)
                }

                then("create an array key") { _ in
                    let key = RemoteConfigKey<[Serializable]?>("test", defaultValue: [defaultValue])
                    XCTAssert(key._key == "test")
                    XCTAssert(key.defaultValue == [defaultValue])
                }

                then("get a default value") { _ in
                    let key = RemoteConfigKey<Serializable?>("test", defaultValue: defaultValue)
                    XCTAssert(config[key] == defaultValue)
                }

                #if swift(>=5.1)
                then("get a default value with dynamicMemberLookup") { _ in
                    keyStore.testOptionalValue = RemoteConfigKey<Serializable?>("test", defaultValue: defaultValue)
                    XCTAssert(config.testOptionalValue == defaultValue)
                }
                #endif

                then("get a default array value") { _ in
                    let key = RemoteConfigKey<[Serializable]?>("test", defaultValue: [defaultValue])
                    XCTAssert(config[key] == [defaultValue])
                }

                #if swift(>=5.1)
                then("get a default array value with dynamicMemberLookup") { _ in
                    keyStore.testOptionalArray = RemoteConfigKey<[Serializable]?>("test", defaultValue: [defaultValue])
                    XCTAssert(config.testOptionalArray == [defaultValue])
                }
                #endif
            }
        }
    }
    
    func testOptionalValuesWithoutDefaultValue(defaultValue: Serializable.T, keyStore: FrogKeyStore<Serializable>) {
        given(String(describing: Serializable.self)) { _ in
            when("key-nil optional value") { _ in
                var config: RemoteConfigAdapter<FrogKeyStore<Serializable>>!
                let remoteConfig = RemoteConfig.remoteConfig()
                config = RemoteConfigAdapter(remoteConfig: remoteConfig,
                                                   keyStore: keyStore)

                then("create a key") { _ in
                    let key = RemoteConfigKey<Serializable?>("test")
                    XCTAssert(key._key == "test")
                    XCTAssertNil(key.defaultValue)
                }

                then("create an array key") { _ in
                    let key = RemoteConfigKey<[Serializable]?>("test")
                    XCTAssert(key._key == "test")
                    XCTAssertNil(key.defaultValue)
                }

                then("compare optional value to non-optional value") { _ in
                    let key = RemoteConfigKey<Serializable?>("test")
                    XCTAssertTrue(config[key] == nil)
                    XCTAssertTrue(config[key] != defaultValue)
                }

                #if swift(>=5.1)
                then("compare optional value to non-optional value with dynamicMemberLookup") { _ in
                    keyStore.testOptionalValue = RemoteConfigKey<Serializable?>("test")
                    XCTAssertTrue(config.testOptionalValue == nil)
                    XCTAssertTrue(config.testOptionalValue != defaultValue)
                }
                #endif
            }
        }
    }
}
