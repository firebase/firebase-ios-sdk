//
//  File.swift
//  File
//
//  Created by Morten Bek Ditlevsen on 14/09/2021.
//

import Foundation

protocol FNode: NSObjectProtocol {
    func isLeafNode() -> Bool
    func getPriority() -> FNode?
    func updatePriority(_ priority: FNode?) -> FNode?
    func getImmediateChild(_ childKey: String?) -> FNode?
    func getChild(_ path: FPath?) -> FNode?
    func predecessorChildKey(_ childKey: String?) -> String?
    func updateImmediateChild(
            _ childKey: String?,
            withNewChild newChildNode: FNode?
        ) -> FNode?
    func updateChild(_ path: FPath?, withNewChild newChildNode: FNode?) -> FNode?
    func hasChild(_ childKey: String?) -> Bool
    var isEmpty: Bool { get }
    func numChildren() -> Int
    func val() -> Any?
    func val(forExport exp: Bool) -> Any?
    func dataHash() -> String?
    func compare(_ other: FNode?) -> ComparisonResult
    func isEqual(_ other: Any?) -> Bool
    func enumerateChildren(usingBlock block: @escaping (_ key: String?, _ node: FNode?, _ stop: UnsafeMutablePointer<ObjCBool>?) -> Void)
    func enumerateChildrenReverse(
            _ reverse: Bool,
            usingBlock block: @escaping (_ key: String?, _ node: FNode?, _ stop: UnsafeMutablePointer<ObjCBool>?) -> Void
        )
    func childEnumerator() -> NSEnumerator?
}
