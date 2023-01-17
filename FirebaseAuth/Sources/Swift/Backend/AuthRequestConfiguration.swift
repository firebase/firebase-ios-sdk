//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 26/06/2022.
//

import Foundation

/** @class FIRAuthRequestConfiguration
    @brief Defines configurations to be added to a request to Firebase Auth's backend.
  */
@objc(FIRAuthRequestConfiguration) public class AuthRequestConfiguration: NSObject {


    /** @property APIKey
     @brief The Firebase Auth API key used in the request.
     */
    @objc public let APIKey: String

    /** @property LanguageCode
     @brief The language code used in the request.
     */
    @objc public var languageCode: String?

    ///** @property appID
    //    @brief The Firebase appID used in the request.
    // */
    @objc public var appID: String
    //
    ///** @property heartbeatLogger
    //    @brief The heartbeat logger used to add heartbeats to the corresponding request's header.
    // */
    @objc public var heartbeatLogger: FIRHeartbeatLoggerProtocol?
    //@property(nonatomic, copy, nullable) id<FIRHeartbeatLoggerProtocol> heartbeatLogger;

    /** @property additionalFrameworkMarker
     @brief Additional framework marker that will be added as part of the header of every request.
     */
    @objc public var additionalFrameworkMarker: String?

    /** @property emulatorHostAndPort
     @brief If set, the local emulator host and port to point to instead of the remote backend.
     */
    @objc public var emulatorHostAndPort: String?

    /** @fn initWithRequestClass:APIKey:authLanguage:
     @brief Designated initializer.
     @param APIKey The API key to be used in the request.
     */
    @objc public init(APIKey: String, appID: String) {
        self.APIKey = APIKey
        self.appID = appID
    }

    @objc public init(APIKey: String, appID: String, heartbeatLogger: FIRHeartbeatLoggerProtocol?) {
        self.APIKey = APIKey
        self.appID = appID
        self.heartbeatLogger = heartbeatLogger
    }

}

