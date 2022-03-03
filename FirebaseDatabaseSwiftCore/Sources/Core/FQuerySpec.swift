//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 03/03/2022.
//

import Foundation

@objc public class FQuerySpec: NSObject, NSCopying {
    @objc public let path: FPath
    @objc public let params: FQueryParams
    @objc public init(path: FPath, params: FQueryParams) {
        self.params = params
        self.path = path
    }

    public func copy(with zone: NSZone? = nil) -> Any {
        // Immutable
        self
    }

    @objc public static func defaultQueryAtPath(_ path: FPath) -> FQuerySpec {
        FQuerySpec(path: path, params: .defaultInstance)
    }

    @objc public var index: FIndex {
        params.index
    }
    @objc public var isDefault: Bool {
        params.isDefault
    }
    @objc public var loadsAllData: Bool {
        params.loadsAllData
    }

    @objc public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? FQuerySpec else { return false }
        if self === other { return true }
        return self.path == other.path && self.params == other.params
    }

    @objc public override var hash: Int {
        var hasher = Hasher()
        path.hash(into: &hasher)
        params.hash(into: &hasher)
        return hasher.finalize()
    }

    @objc public override var description: String {
        "FQuerySpec (path: \(path), params: \(params)"
    }
}
