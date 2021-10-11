//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 23/09/2021.
//

import Foundation

let kPayloadValue = ".value"
let kPayloadPriority = ".priority"

@objc public class FLeafNode: NSObject, FNode {
    public func isLeafNode() -> Bool {
        true
    }

    public func getPriority() -> FNode {
        priority
    }

    public func updatePriority(_ priority: FNode) -> FNode {
        FLeafNode(value: value, withPriority: priority)
    }

    public func getImmediateChild(_ childKey: String) -> FNode {
        if childKey == ".priority" {
            return priority
        } else {
            return FEmptyNode.emptyNode
        }
    }

    public func getChild(_ path: FPath) -> FNode {
        guard let front = path.getFront() else {
            return self
        }
        if front == ".priority" {
            return priority
        } else {
            return FEmptyNode.emptyNode
        }
    }

    public func predecessorChildKey(_ childKey: String) -> String? {
        nil
    }

    public func updateImmediateChild(_ childKey: String, withNewChild newChildNode: FNode) -> FNode {
        if childKey == ".priority" {
            return updatePriority(newChildNode)
        } else if newChildNode.isEmpty {
            return self
        } else {
            return FChildrenNode()
                .updateImmediateChild(childKey, withNewChild: newChildNode)
                .updatePriority(priority)
        }
    }

    public func updateChild(_ path: FPath, withNewChild newChildNode: FNode) -> FNode {
        guard let front = path.getFront() else {
            return newChildNode
        }
        if newChildNode.isEmpty && front != ".priority" {
            return self
        } else {
            assert(front != ".priority" || path.length() == 1, ".priority must be the last token in a path.")
            return self.updateImmediateChild(front, withNewChild: FEmptyNode.emptyNode.updateChild(path.popFront(), withNewChild: newChildNode))
        }
    }

    public func hasChild(_ childKey: String) -> Bool {
        childKey == ".priority" && !priority.isEmpty
    }

    public var isEmpty: Bool {
        false
    }

    public func numChildren() -> Int {
        0
    }

    public func val() -> Any {
        val(forExport: false)
    }

    public func val(forExport exp: Bool) -> Any {
        if exp && !priority.isEmpty {
            return [
                kPayloadValue: value,
                kPayloadPriority: priority.val()
            ] as NSDictionary
        } else {
            return value
        }
    }

    public func dataHash() -> String {
        if let lazyHash = lazyHash {
            return lazyHash
        }
        var toHash = ""
        FSnapshotUtilitiesSwift.appendHashRepresentation(for: self, to: &toHash, hashVersion: .v1)
        let calculatedHash = FUtilitiesSwift.base64EncodedSha1(toHash)
        lazyHash = calculatedHash
        return calculatedHash;
    }

    public func compare(_ other: FNode) -> ComparisonResult {
        if let other = other as? FChildrenNode, other === FEmptyNode.emptyNode {
            return .orderedDescending
        } else if other is FChildrenNode {
            return .orderedAscending
        } else if let other = other as? FLeafNode {
            return compareToLeafNode(other)
        }
        assert(false, "Compared against unknown type of node.")
        return .orderedAscending
    }

    private func compareToLeafNode(_ other: FLeafNode) -> ComparisonResult {
        let thisLeafType = FUtilitiesSwift.getJavascriptType(value)
        let thisIndex = thisLeafType.order
        let otherIndex = FUtilitiesSwift.getJavascriptType(other.value).order
        if otherIndex == thisIndex {
            // Same type.  Compare values.
            switch thisLeafType {
            case .object:
                // Deferred value nodes are all equal, but we should also never get
                // to this point...
                return .orderedSame
            case .string:
                return (value as! NSString).compare(other.value as! String, options: .literal)

            case .number, .boolean:
                return (value as! NSNumber).compare(other.value as! NSNumber)
            case .null:
                return .orderedSame
            }
        } else {
            return thisIndex > otherIndex ? .orderedDescending
            : .orderedAscending
        }
    }

    public func enumerateChildren(usingBlock block: @escaping (String, FNode, UnsafeMutablePointer<ObjCBool>) -> Void) {
        // Nothing to iterate over
    }

    public func enumerateChildrenReverse(_ reverse: Bool, usingBlock block: @escaping (String, FNode, UnsafeMutablePointer<ObjCBool>) -> Void) {
        // Nothing to iterate over
    }

    public func childEnumerator() -> NSEnumerator {
        // Nothing to iterate over
        NSArray().objectEnumerator()
    }

    public override var hash: Int {
        guard let v = value as? NSObject else {
            return priority.hash
        }
        #warning("fishy")
        return v.hash &* 17 &+ priority.hash
    }

    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? FLeafNode else {
            return false
        }
        if other === self {
            return true
        }
        guard FUtilitiesSwift.getJavascriptType(value) == FUtilitiesSwift.getJavascriptType(other.value) else {
            return false
        }
#warning("fishy")
        guard let v = value as? NSObject,
              let ov = other.value as? NSObject else {
                  return false
              }
        return v.isEqual(ov) && priority.isEqual(other.priority)
    }

    @objc public let value: Any
    let priority: FNode
    var lazyHash: String?

    @objc public init(value: Any) {
        self.value = value
        self.priority = FEmptyNode.emptyNode
    }

    @objc public init(value: Any, withPriority priority: FNode) {
        self.value = value
        FSnapshotUtilitiesSwift.validatePriorityNode(priority)

        self.priority = priority
    }
    public override var description: String {
        "\(val(forExport: true))"
    }
}

enum JavaScriptType: String {
    case object
    case boolean
    case number
    case string
    case null
    var order: Int {
        switch self {
        case .object: return 0
        case .boolean: return 1
        case .number: return 2
        case .string: return 3
        case .null: return 4
        }
    }
}

/*
+ (NSString *)getJavascriptType:(id)obj {
    if ([obj isKindOfClass:[NSDictionary class]]) {
        return kJavaScriptObject;
    } else if ([obj isKindOfClass:[NSString class]]) {
        return kJavaScriptString;
    } else if ([obj isKindOfClass:[NSNumber class]]) {
        // We used to just compare to @encode(BOOL) as suggested at
        // http://stackoverflow.com/questions/2518761/get-type-of-nsnumber, but
        // on arm64, @encode(BOOL) returns "B" instead of "c" even though
        // objCType still returns 'c' (signed char).  So check both.
        if (strcmp([obj objCType], @encode(BOOL)) == 0 ||
            strcmp([obj objCType], @encode(signed char)) == 0) {
            return kJavaScriptBoolean;
        } else {
            return kJavaScriptNumber;
        }
    } else {
        return kJavaScriptNull;
    }
}
*/
