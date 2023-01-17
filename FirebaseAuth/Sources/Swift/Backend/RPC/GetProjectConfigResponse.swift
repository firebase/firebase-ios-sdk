//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 04/10/2022.
//

import Foundation

@objc(FIRGetProjectConfigResponse) public class GetProjectConfigResponse: NSObject, AuthRPCResponse {

    /** @property projectID
        @brief The unique ID pertaining to the current project.
     */
    @objc public var projectID: String?

    /** @property authorizedDomains
        @brief A list of domains allowlisted for the current project.
     */
    @objc public var authorizedDomains: [String]?

    public func setFields(dictionary: [String : Any]) throws {
        self.projectID = dictionary["projectId"] as? String
        if let authorizedDomains = dictionary["authorizedDomains"] as? String, let data = authorizedDomains.data(using: .utf8) {

            if let decoded = try? JSONSerialization.jsonObject(with: data, options: [.mutableLeaves]), let array = decoded as? [String] {
                self.authorizedDomains = array
            }
        } else if let authorizedDomains = dictionary["authorizedDomains"] as? [String] {
            self.authorizedDomains = authorizedDomains
        }
    }
}
