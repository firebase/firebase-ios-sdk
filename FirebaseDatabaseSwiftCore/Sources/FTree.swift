//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 19/02/2022.
//

import Foundation

@objc public class FTree: NSObject {
  @objc public var parent: FTree?
  @objc public var name: String
  private var node: FTreeNode
  @objc public override init() {
    self.name = ""
    self.node = FTreeNode()
  }
  init(name: String?, parent: FTree?, node: FTreeNode?) {
    self.name = name ?? ""
    self.parent = parent
    self.node = node ?? FTreeNode()
  }
  @objc public func subTree(_ path: FPath) -> FTree {
    var path = path
    var child = self
    var nextOptional = path.getFront()
    while let next = nextOptional {
      let childNode = child.node.children[next] ?? FTreeNode()
      child = FTree(name: next, parent: child, node: childNode)
      path = path.popFront()
      nextOptional = path.getFront()
    }
    return child
  }
  @objc public func getValue() -> Any? {
    node.value
  }
  @objc public func setValue(_ value: Any?) {
    node.value = value
    updateParents()
  }
  func clear() {
    node.value = nil
    node.children = [:]
    node.childCount = 0
    updateParents()
  }
  @objc public var hasChildren: Bool {
    node.childCount > 0
  }

  @objc public var isEmpty: Bool {
    !hasChildren && getValue() == nil
  }

  func updateParents() {
    parent?.updateChild(self.name, withNode: self)
  }

  @objc public var path: FPath {
    FPath(with: parent.map { "\($0.path)/\(name)" } ?? name)
  }

  func updateChild(_ childName: String, withNode child: FTree) {
    let childEmpty = child.isEmpty
    let childExists = node.children[childName] != nil
    if childEmpty && childExists {
      node.children.removeValue(forKey: childName)
      node.childCount -= 1
      updateParents()
    } else if !childEmpty && !childExists {
      node.children[childName] = child.node
      node.childCount += 1
      updateParents()
    }
  }

  func valueExistsAtOrAbove(path: FPath) -> Bool {
    var path = path
    var aNode: FTreeNode? = node
    while let bNode = aNode, let front = path.getFront()  {
      if bNode.value != nil {
        return true
      }
      aNode = bNode.children[front]
      path = path.popFront()
    }
    // XXX Check with Michael if this is correct; deviates from JS.
    return false
  }

  @objc public func forEachChild(_ action: (FTree) -> Void) {
    for (key, node) in node.children {
      action(FTree(name: key, parent: self, node: node))
    }
  }

  @objc public func forEachDescendant(_ action: (FTree) -> Void) {
    forEachDescendant(action, includeSelf: false, childrenFirst: false)
  }

  func forEachDescendant(_ action: (FTree) -> Void, includeSelf: Bool, childrenFirst: Bool) {
    if includeSelf && !childrenFirst {
      action(self)
    }
    forEachChild { child in
      child.forEachDescendant(action, includeSelf: true, childrenFirst: childrenFirst)
    }
    if includeSelf && childrenFirst {
      action(self)
    }
  }

  @objc public func forEachAncestor(_ action: (FTree) -> Bool) -> Bool {
    forEachAncestor(action, includeSelf: false)
  }
  func forEachAncestor(_ action: (FTree) -> Bool, includeSelf: Bool) -> Bool {
    var aNode = includeSelf ? self : self.parent
    while let bNode = aNode {
      if action(bNode) {
        return true
      }
      aNode = bNode.parent
    }
    return false
  }
}
