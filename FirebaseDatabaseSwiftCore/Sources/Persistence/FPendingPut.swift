//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 05/03/2022.
//

import Foundation

@objc public class FPendingPut: NSObject, NSCoding {
    @objc public let path: FPath
    @objc public let priority: Any
    @objc public let data: Any

    @objc public init(path: FPath, andData data: Any, andPriority priority: Any) {
        self.path = path
        self.priority = priority
        self.data = data
    }

    public func encode(with coder: NSCoder) {
        coder.encode(path.description, forKey: "path")
        coder.encode(priority, forKey: "priority")
        coder.encode(data, forKey: "data")
    }
    public required init?(coder: NSCoder) {
        guard let path = coder.decodeObject(forKey: "path") as? String else {
            return nil
        }
        self.path = FPath(with: path)
        guard let priority = coder.decodeObject(forKey: "priority") else {
            return nil
        }
        self.priority = priority

        guard let data = coder.decodeObject(forKey: "data") else {
            return nil
        }
        self.data = data

    }
}



@objc public class FPendingPutPriority: NSObject, NSCoding {
    @objc public let path: FPath
    @objc public let priority: Any
    @objc public init(path: FPath, andPriority priority: Any) {
        self.path = path
        self.priority = priority
    }

    public func encode(with coder: NSCoder) {
        coder.encode(path.description, forKey: "path")
        coder.encode(priority, forKey: "priority")
    }
    public required init?(coder: NSCoder) {
        guard let path = coder.decodeObject(forKey: "path") as? String else {
            return nil
        }
        self.path = FPath(with: path)
        guard let priority = coder.decodeObject(forKey: "priority") else {
            return nil
        }
        self.priority = priority
    }
}

@objc public class FPendingUpdate: NSObject, NSCoding {
    @objc public let path: FPath
    @objc public let data: NSDictionary
    @objc public init(path: FPath, andData data: NSDictionary) {
        self.path = path
        self.data = data
    }

    public func encode(with coder: NSCoder) {
        coder.encode(path.description, forKey: "path")
        coder.encode(data, forKey: "data")
    }
    public required init?(coder: NSCoder) {
        guard let path = coder.decodeObject(forKey: "path") as? String else {
            return nil
        }
        self.path = FPath(with: path)
        guard let data = coder.decodeObject(forKey: "data") as? NSDictionary else {
            return nil
        }
        self.data = data
    }
}
