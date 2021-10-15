//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 11/10/2021.
//

import Collections
import Foundation

let kFirebaseMaxObjectDepth = 1000
let kPayloadMetadataPrefix = "."

@objc public class FSnapshotUtilities: NSObject {
    @objc public static func nodeFrom(_ val: Any?) -> FNode {
        FSnapshotUtilitiesSwift.nodeFrom(val, priority: nil)
    }

    @objc public static func nodeFrom(_ val: Any?, withValidationFrom fn: String) -> FNode {
        FSnapshotUtilitiesSwift.nodeFrom(val, withValidationFrom: fn)
    }
    @objc public static func nodeFrom(_ val: Any?, priority: Any?) -> FNode {
        FSnapshotUtilitiesSwift.nodeFrom(val, priority: priority)
    }
    @objc public static func nodeFrom(_ val: Any?, priority: Any?, withValidationFrom fn: String) -> FNode {
        FSnapshotUtilitiesSwift.nodeFrom(val, priority: priority, withValidationFrom: fn)
    }

    @objc public static func appendHashV2Representation(for string: String, to mutableString: NSMutableString) {
        var mutable: String = String(mutableString)
        FSnapshotUtilitiesSwift.appendHashV2Representation(for: string, to: &mutable)
        mutableString.setString(mutable)
    }

    @objc public static func appendHashRepresentationV2ForLeafNode(_ node: FNode, to mutableString: NSMutableString) {
        var mutable: String = String(mutableString)
        FSnapshotUtilitiesSwift.appendHashRepresentation(for: node, to: &mutable, hashVersion: .v2)
        mutableString.setString(mutable)
    }

    @objc public static func compoundWriteFromDictionary(_ values: NSDictionary, withValidationFrom fn: String) -> FCompoundWrite {
        var compoundWrite = FCompoundWrite.emptyWrite
        var updatePaths: [FPath] = []
        for keyId in values.allKeys {
            let value = values[keyId]
            let key = FValidationSwift.validateFrom(fn, validUpdateDictionaryKey: keyId, withValue: value as Any)
            let path = FPath(with: key)
            let node = FSnapshotUtilitiesSwift.nodeFrom(value, withValidationFrom: fn)
            updatePaths.append(path)
            compoundWrite = compoundWrite.addWrite(node, atPath: path)
        }
        // Check that the update paths are not descendants of each other.
        updatePaths.sort { a, b in
            a.compare(b) == .orderedAscending
        }
        var prevPath: FPath? = nil
        for path in updatePaths {
            if let prev = prevPath, prev.contains(path) {
                fatalError("(\(fn)) Invalid path in object. Path (\(prev)) is an ancestor of (\(path)).")
            }
            prevPath = path
        }
        return compoundWrite
    }

    // Move to enum and remove this once swift conversion of usage points is done
    #warning("TODO - MOVE")
    @objc public static func estimateSerializedNodeSize(_ node: FNode) -> Int {
        if node.isEmpty {
            return 4 // null keyword
        } else if node.isLeafNode() {
            return estimateLeafNodeSize(node)
        } else if let childrenNode = node as? FChildrenNode {
            var sum = 1 // opening brackets
            for (key, child) in childrenNode.children {
                sum += key.count
                sum += 4 // quotes around key and colon and (comma or closing bracket)
                sum += estimateSerializedNodeSize(child)
            }
            return sum

        } else {
            assert(false, "Unexpected node type: \(type(of: node))")
            return 0
        }
    }
    // Move to enum and remove this once swift conversion of usage points is done
    #warning("TODO - MOVE")
    static func estimateLeafNodeSize(_ node: FNode) -> Int {
        // These values are somewhat arbitrary, but we don't need an exact value so
        // prefer performance over exact value
        let valueSize: Int
        switch FUtilitiesSwift.getJavascriptType(node.val()) {
        case .number:
            valueSize = 8 // estimate each float with 8 bytes
        case .boolean:
            valueSize = 4 // true or false need roughly 4 bytes
        case .string:
            // If we are measuring bytes here then we should use the utf8 view here, right?
            valueSize = 2 + ((node.val() as? String)?.utf8.count ?? 0) // add 2 for quotes
        default:
            fatalError("Unknown leaf type: \(node)")
        }
        if node.getPriority().isEmpty {
            return valueSize
        } else {
            // Account for extra overhead due to the extra JSON object and the
            // ".value" and ".priority" keys, colons, comma
            let leafPriorityOverhead = 2 + 8 + 11 + 2 + 1;
            return leafPriorityOverhead + valueSize +
            estimateLeafNodeSize(node.getPriority())
        }
    }
}

public enum FSnapshotUtilitiesSwift {
    enum FDataHashVersion {
        case v1
        case v2
    }

    public static func nodeFrom(_ val: Any?) -> FNode {
        nodeFrom(val, priority: nil)
    }

    public static func nodeFrom(_ val: Any?, priority: Any?) -> FNode {
        nodeFrom(val, priority: priority, withValidationFrom: "nodeFrom:priority:")
    }

    public static func nodeFrom(_ val: Any?, withValidationFrom fn: String) -> FNode {
        var path: [String] = []
        return nodeFrom(val, priority: nil, withValidationFrom: fn, atDepth: 0, path: &path)
    }

    public static func nodeFrom(_ val: Any?, priority: Any?, withValidationFrom fn: String) -> FNode {
        var path: [String] = []
        return nodeFrom(val, priority: priority, withValidationFrom: fn, atDepth: 0, path: &path)
    }

    public static func nodeFrom(_ val: Any?, priority: Any?, withValidationFrom fn: String, atDepth depth: Int, path: inout [String]) -> FNode {
        internalNodeFrom(val, priority: priority, withValidationFrom: fn, atDepth: depth, path: &path)
    }

     public static func internalNodeFrom(_ val: Any?, priority: Any?, withValidationFrom fn: String, atDepth depth: Int, path: inout [String]) -> FNode {
         guard depth <= kFirebaseMaxObjectDepth else {
             let pathString = path[0..<100].joined(separator: ".")
             fatalError("(\(fn)) Max object depth exceeded: \(pathString)...")
         }
         if val == nil || (val as? NSNull) === NSNull() {
             return FEmptyNode.emptyNode
         }
         var value = val
         FValidationSwift.validateFrom(fn, isValidPriorityValue: priority as Any, withPath: path)
         var priority = FSnapshotUtilitiesSwift.nodeFrom(priority)
         var isLeafNode = false
         if let dict = val as? NSDictionary {
             if let rawPriority = dict[kPayloadPriority] {
                 FValidationSwift.validateFrom(fn, isValidPriorityValue: rawPriority, withPath: path)
                 priority = nodeFrom(rawPriority)
             }
             if let payload = dict[kPayloadValue] {
                 value = payload
                 if FValidationSwift.validateFrom(fn, isValidLeafValue: value, withPath: path) {
                     isLeafNode = true
                 } else {
                     fatalError("(\(fn)) Invalid data type used with .value. Can only use NSString and NSNumber or be null. Found \(type(of: value)) instead.")
                 }
             }
         }
         if !isLeafNode && FValidationSwift.validateFrom(fn, isValidLeafValue: value, withPath: path) {
             isLeafNode = true
         }

         if isLeafNode {
             return FLeafNode(value: value as Any, withPriority: priority)
         }

         // Unlike with JS, we have to handle the dictionary and array cases
         // separately.

         if let dval = value as? NSDictionary {
             var children: [String: FNode] = .init(minimumCapacity: dval.count)

             // Avoid creating a million newPaths by appending to old one
             for keyId in dval.allKeys {
                 let key = FValidationSwift.validateFrom(fn, validDictionaryKey: keyId, withPath: path)
                 if !key.hasPrefix(kPayloadMetadataPrefix) {
                     path.append(key)
                     let childNode = nodeFrom(dval[key], priority: nil, withValidationFrom: fn, atDepth: depth + 1, path: &path)
                     path.removeLast()
                     if !childNode.isEmpty {
                         children[key] = childNode
                     }
                 }
             }
             if children.isEmpty {
                 return FEmptyNode.emptyNode
             } else {
                 var dict = OrderedDictionary(uncheckedUniqueKeys: children.keys, values: children.values)
                 dict.sort { a, b in
                     FUtilitiesSwift.compareKey(a.key, b.key) == .orderedAscending
                 }

                 return FChildrenNode(priority: priority, children: dict)
             }
         } else if let aval = value as? NSArray {
             var children: [String: FNode] = .init(minimumCapacity: aval.count)

             for i in 0..<aval.count {
                 let key = "\(i)"
                 path.append(key)
                 let childNode = nodeFrom(aval[i], priority: nil, withValidationFrom: fn, atDepth: depth + 1, path: &path)
                 path.removeLast()

                 if !childNode.isEmpty {
                     children[key] = childNode
                 }
             }

             if children.isEmpty {
                 return FEmptyNode.emptyNode
             } else {
                 var dict = OrderedDictionary(uncheckedUniqueKeys: children.keys, values: children.values)
                 dict.sort { a, b in
                     FUtilitiesSwift.compareKey(a.key, b.key) == .orderedAscending
                 }

                 return FChildrenNode(priority: priority, children: dict)
             }
         } else {
             let pathString = path.prefix(50).joined(separator: ".")
             fatalError("(\(fn)) Cannot store object of type \(type(of: value)) at \(pathString). Can only store objects of type NSNumber, NSString, NSDictionary, and NSArray.")
         }
     }

    static func validatePriorityNode(_ priorityNode: FNode) {
        if priorityNode.isLeafNode() {
            let val = priorityNode.val()
            if let valDict = val as? NSDictionary {
                assert(valDict[kServerValueSubKey] != nil, "Priority can't be object unless it's a deferred value")
            } else {
                let jsType = FUtilitiesSwift.getJavascriptType(val)
                assert(jsType == .string || jsType == .number, "Priority of unexpected type.")
            }
        } else {
            assert (priorityNode === FMaxNode.maxNode || priorityNode.isEmpty, "Priority of unexpected type.")
        }
        // Don't call getPriority() on MAX_NODE to avoid hitting assertion.
        assert (priorityNode === FMaxNode.maxNode || priorityNode.getPriority().isEmpty, "Priority nodes can't have a priority of their own.")
    }

    static func appendHashRepresentation(for leafNode: FNode, to output: inout String, hashVersion: FDataHashVersion) {
        if !leafNode.getPriority().isEmpty {
            output += "priority:"
            appendHashRepresentation(for: leafNode.getPriority(),
                                        to: &output,
                                        hashVersion: hashVersion)
            output += ":"
        }
        let jsType = FUtilitiesSwift.getJavascriptType(leafNode.val())
        output += jsType.rawValue + ":"
        switch jsType {
        case .object:
            fatalError("Unknown value for hashing: \(leafNode)")

        case .boolean:
            let numberVal = (leafNode.val() as? NSNumber) ?? NSNumber(booleanLiteral: false)
            output += numberVal.boolValue ? "true" : "false"
        case .number:
            let numberVal = (leafNode.val() as? NSNumber) ?? NSNumber(integerLiteral: 0)

            output += FUtilitiesSwift.ieee754String(for: numberVal)
        case .string:
            let stringVal = (leafNode.val() as? String) ?? ""
            switch hashVersion {
            case .v1:
                output += stringVal
            case .v2:
                appendHashV2Representation(for: stringVal, to: &output)
            }
        case .null:
            ()
        }
    }

    static func appendHashV2Representation(for string: String, to output: inout String) {
        output += "\""
        output += string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        output += "\""
    }

}
