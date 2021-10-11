//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 11/10/2021.
//

import Foundation

@objc public class FParsedUrl: NSObject {
    @objc public var repoInfo: FRepoInfo
    @objc public var path: FPath
    @objc public init(repoInfo: FRepoInfo, path: FPath) {
        self.repoInfo = repoInfo
        self.path = path
    }
}
