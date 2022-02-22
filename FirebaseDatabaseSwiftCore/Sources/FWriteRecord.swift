//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 19/02/2022.
//

import Foundation

struct FWriteRecordImpl: Hashable, Equatable {
  static func == (lhs: FWriteRecordImpl, rhs: FWriteRecordImpl) -> Bool {
    let oEqual: Bool
    if let lo = lhs.overwrite, let ro = rhs.overwrite {
      oEqual = lo.isEqual(ro)
    } else if lhs.overwrite == nil && rhs.overwrite == nil {
      oEqual = true
    } else {
      oEqual = false
    }
    return (
      lhs.writeId == rhs.writeId &&
      lhs.visible == rhs.visible &&
      lhs.path == rhs.path &&
      lhs.merge == rhs.merge &&
      oEqual
    )
  }

  let writeId: Int
  let path: FPath
  // TODO: Overwrite or merge are mutually exclusive
  // and as such they should be two cases of an enum
  let overwrite: FNode?
  let merge: FCompoundWrite?
  let visible: Bool
  init(path: FPath, overwrite: FNode, writeId: Int, visible: Bool) {
    self.path = path
    self.overwrite = overwrite
    self.merge = nil
    self.writeId = writeId
    self.visible = visible
  }

  init(path: FPath, merge: FCompoundWrite, writeId: Int) {
    self.path = path
    self.merge = merge
    self.overwrite = nil
    self.writeId = writeId
    self.visible = true
  }
  var isMerge: Bool {
    merge != nil
  }

  var isOverwrite: Bool {
    overwrite != nil
  }

  func hash(into hasher: inout Hasher) {
    writeId.hash(into: &hasher)
    path.hash(into: &hasher)
    if let overwrite = overwrite {
      overwrite.hash.hash(into: &hasher)
    } else {
      NSNull().hash(into: &hasher)
    }
    merge.hash(into: &hasher)
    visible.hash(into: &hasher)
  }

  var debugDescription: String {
    if let overwrite = overwrite {
      return "FWriteRecord { writeId = \(writeId), path = \(path), overwrite = \(overwrite), visible = \(visible) }"
    } else {
      return "FWriteRecord { writeId = \(writeId), path = \(path), merge = \(merge!) }"
    }
  }
}

protocol Ski: Hashable {}


@objc public class FWriteRecord: NSObject {
  let impl: FWriteRecordImpl

  @objc public init(path: FPath, overwrite: FNode, writeId: Int, visible: Bool) {
    self.impl = FWriteRecordImpl(path: path, overwrite: overwrite, writeId: writeId, visible: visible)
  }

  @objc public init(path: FPath, merge: FCompoundWrite, writeId: Int) {
    self.impl = .init(path: path, merge: merge, writeId: writeId)
  }

  @objc public var writeId: Int { impl.writeId }
  @objc public var visible: Bool { impl.visible }
  @objc public var path: FPath { impl.path }
  @objc public var isOverwrite: Bool { impl.isOverwrite }
  @objc public var isMerge: Bool { impl.isMerge }
  @objc public var overwrite: FNode? { impl.overwrite }
  @objc public var merge: FCompoundWrite? { impl.merge }
    @objc public override var hash: Int { impl.hashValue }
    @objc public override var debugDescription: String {
        impl.debugDescription
    }

    @objc public override var description: String {
        impl.debugDescription
    }

    @objc public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? FWriteRecord else { return false }
        return other.impl == self.impl
    }
}
