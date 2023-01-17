//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 27/09/2022.
//

import Foundation

/** @var kGetProjectConfigEndPoint
    @brief The "getProjectConfig" endpoint.
 */
private let kGetProjectConfigEndPoint = "getProjectConfig"

@objc(FIRGetProjectConfigRequest) public class GetProjectConfigRequest: IdentityToolkitRequest, AuthRPCRequest {

    @objc public init(requestConfiguration: AuthRequestConfiguration) {
        super.init(endpoint: kGetProjectConfigEndPoint, requestConfiguration: requestConfiguration)
    }

    public func unencodedHTTPRequestBody() throws -> Any {
        // XXX TODO
        fatalError()
    }

    public override func containsPostBody() -> Bool { false }
}
