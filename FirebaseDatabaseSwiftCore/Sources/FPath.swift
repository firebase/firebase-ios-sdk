//
//  File.swift
//  File
//
//  Created by Morten Bek Ditlevsen on 14/09/2021.
//

import Foundation

private let emptyPath = FPath(with: "")

@objc public class FPath: NSObject, NSCopying {
    let pieceNum: Int
    let pieces: [String]

    @objc public class func relativePath(from outer: FPath, to inner: FPath) -> FPath {
        guard let outerFront = outer.getFront() else {
            return inner
        }
        let innerFront = inner.getFront()
        if outerFront == innerFront {
            return relativePath(from: outer.popFront(), to: inner.popFront())
        } else {
            fatalError()
//            @throw [[NSException alloc]
//                initWithName:@"FirebaseDatabaseInternalError"
//                      reason:[NSString
//                                 stringWithFormat:
//                                     @"innerPath (%@) is not within outerPath (%@)",
//                                     inner, outer]
//                    userInfo:nil];
        }
    }

    @objc public class var empty: FPath { emptyPath }

    @objc public class func path(string: String) -> FPath {
        FPath(with: string)
    }

    @objc public init(with path: String) {
        let pathPieces = path.components(separatedBy: "/")
        self.pieces = pathPieces.filter {
            !$0.isEmpty
        }
        self.pieceNum = 0
    }

    @objc public init(pieces: [String], andPieceNum pieceNum: Int) {
        self.pieces = pieces
        self.pieceNum = pieceNum
    }

    @objc public func copy(with zone: NSZone? = nil) -> Any {
        // Immutable, so it's safe to return self
        return self
    }

    @objc public func enumerateComponents(usingBlock block: @escaping (_ key: String, _ stop: UnsafeMutablePointer<ObjCBool>) -> Void) {
        var stop: ObjCBool = false
        for piece in pieces[pieceNum...] {
            withUnsafeMutablePointer(to: &stop) { pointer in
                block(piece, pointer)
            }
            if stop.boolValue { break }
        }
    }

    @objc public func getFront() -> String? {
        guard pieceNum < pieces.count else {
            return nil
        }
        return pieces[pieceNum]
    }

    @objc public func length() -> Int {
        pieces.count - pieceNum
    }

    @objc public func popFront() -> FPath {
        var newPieceNum = pieceNum
        if newPieceNum < pieces.count {
            newPieceNum += 1
        }
        return FPath(pieces: pieces, andPieceNum: newPieceNum)
    }

    @objc public func getBack() -> String? {
        pieces.last
    }

    @objc public func toString() -> String {
        toString(withTrailingSlash: false)
    }

    @objc public override var description: String {
        toString()
    }

    @objc public func toStringWithTrailingSlash() -> String {
        toString(withTrailingSlash: true)
    }

    private func toString(withTrailingSlash trailingSlash: Bool) -> String {
        var pathString = ""
        for piece in pieces[pieceNum...] {
            pathString += "/\(piece)"
        }

        if pathString.isEmpty {
            return "/"
        } else {
            if trailingSlash {
                return pathString + "/"
            }
            return pathString
        }
    }

    @objc public func wireFormat() -> String {
        isEmpty ? "/" : pieces[pieceNum...].joined(separator: "/")
    }

    @objc public func parent() -> FPath? {
        guard pieceNum < pieces.count else {
            return nil
        }
        
        return FPath(pieces: Array(pieces[pieceNum..<(pieces.count - 1)]), andPieceNum: 0)
    }

    @objc public func child(_ childPathObj: FPath) -> FPath {
        var newPieces = Array(pieces[pieceNum...])
        newPieces.append(contentsOf: childPathObj.pieces[childPathObj.pieceNum...])
        return FPath(pieces: newPieces, andPieceNum: 0)
    }

    @objc public func child(fromString childPath: String) -> FPath {
        var newPieces = Array(pieces[pieceNum...])

        let pathPieces = childPath.components(separatedBy: "/")
        newPieces.append(contentsOf: pathPieces.filter {
            !$0.isEmpty
        })

        return FPath(pieces: newPieces, andPieceNum: 0)
    }

    @objc public var isEmpty: Bool {
        pieceNum >= pieces.count
    }

    @objc public func contains(_ other: FPath) -> Bool {
        guard self.length() <= other.length() else {
            return false
        }

        for (a, b) in zip(pieces[pieceNum...], other.pieces[other.pieceNum...]) {
            if a != b {
                return false
            }
        }
        return true
    }

    @objc public func compare(_ other: FPath) -> ComparisonResult {
        for (a, b) in zip(pieces[pieceNum...], other.pieces[other.pieceNum...]) {
            let comparison = FUtilitiesSwift.compareKey(a, b)
            if comparison != .orderedSame {
                return comparison;
            }
        }
        if (self.length() < other.length()) {
            return .orderedAscending
        } else if other.length() < self.length() {
            return .orderedDescending
        } else {
            assert(self.length() == other.length(),
                     "Paths must be the same lengths")
            return .orderedSame
        }

    }

    @objc override public func isEqual(_ other: Any?) -> Bool {
        guard let other = other as? FPath else { return false }
        if other === self {
            return true
        }
        if length() != other.length() {
            return false
        }
        for (a, b) in zip(pieces[pieceNum...], other.pieces[other.pieceNum...]) {
            if a != b { return false }
        }
        return true
    }

    @objc override public var hash: Int {
        var hasher = Hasher()
        for piece in pieces[pieceNum...] {
            piece.hash(into: &hasher)
        }
        return hasher.finalize()
    }
}
