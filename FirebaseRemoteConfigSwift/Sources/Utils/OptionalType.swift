//
//  OptionalType.swift
//  RemoteConfigSwift
//
//  Created by 伊藤史 on 2020/08/21.
//  Copyright © 2020 Fumito Ito. All rights reserved.
//

protocol OptionalTypeCheck {
    var isNil: Bool { get }
}

public protocol OptionalType {
    associatedtype Wrapped

    var wrapped: Wrapped? { get }

    static var empty: Self { get }
}

extension Optional: OptionalType, OptionalTypeCheck {
    public var wrapped: Wrapped? {
        return self
    }

    public static var empty: Optional {
        return nil
    }

    var isNil: Bool {
        return self == nil
    }
}
