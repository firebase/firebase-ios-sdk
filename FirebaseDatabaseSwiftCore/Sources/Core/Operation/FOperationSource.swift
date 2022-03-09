//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 09/03/2022.
//

import Foundation

@objc public class FOperationSource: NSObject {
    @objc public let fromUser: Bool
    @objc public let fromServer: Bool
    @objc public let isTagged: Bool
    @objc public let queryParams: FQueryParams?
    public init(fromUser isFromUser: Bool, fromServer isFromServer: Bool, queryParams: FQueryParams?, tagged isTagged: Bool) {
        self.isTagged = isTagged
        self.fromUser = isFromUser
        self.fromServer = isFromServer
        self.queryParams = queryParams
    }

    @objc public static var userInstance: FOperationSource = .init(fromUser: true,
                                                                   fromServer: false,
                                                                   queryParams: nil,
                                                                   tagged: false)

    @objc public static var serverInstance: FOperationSource = .init(fromUser: false,
                                                                   fromServer: true,
                                                                   queryParams: nil,
                                                                   tagged: false)

    @objc public static func forServerTaggedQuery(_ params: FQueryParams) -> FOperationSource {
        .init(fromUser: false, fromServer: true, queryParams: params, tagged: true)
    }

    public override var description: String {
        "FOperationSource { fromUser=\(fromUser), fromServer=\(fromServer), queryParams=\(queryParams), tagged=\(isTagged) }"
    }
}
