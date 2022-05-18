//
//  File.swift
//  File
//
//  Created by Morten Bek Ditlevsen on 14/09/2021.
//

import Foundation

@objc public protocol FNode: NSObjectProtocol {
    @objc func isLeafNode() -> Bool
    @objc func getPriority() -> FNode
    @objc func updatePriority(_ priority: FNode) -> FNode
    @objc func getImmediateChild(_ childKey: String) -> FNode
    @objc func getChild(_ path: FPath) -> FNode
    @objc func predecessorChildKey(_ childKey: String) -> String?
    @objc func updateImmediateChild(
            _ childKey: String,
            withNewChild newChildNode: FNode
        ) -> FNode
    @objc func updateChild(_ path: FPath, withNewChild newChildNode: FNode) -> FNode
    @objc func hasChild(_ childKey: String) -> Bool
    @objc var isEmpty: Bool { get }
    @objc func numChildren() -> Int
    @objc func val() -> Any
    @objc func val(forExport exp: Bool) -> Any
    @objc func dataHash() -> String
    @objc func compare(_ other: FNode) -> ComparisonResult
    @objc func isEqual(_ other: Any?) -> Bool
    @objc func enumerateChildren(usingBlock block: @escaping (_ key: String, _ node: FNode, _ stop: UnsafeMutablePointer<ObjCBool>) -> Void)
    @objc func enumerateChildrenReverse(
            _ reverse: Bool,
            usingBlock block: @escaping (_ key: String, _ node: FNode, _ stop: UnsafeMutablePointer<ObjCBool>) -> Void
        )
//    @objc func childEnumerator() -> NSEnumerator
}
