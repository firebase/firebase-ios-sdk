//
//  File.swift
//  File
//
//  Created by Morten Bek Ditlevsen on 21/09/2021.
//

// NOTE: This is just a placeholder class until all usages of FImmutableSortedDictionary are gone
import Collections
import Foundation

@objc public class FImmutableSortedDictionary: NSObject {
    let dict: OrderedDictionary<String, FNode>
    init(dict: OrderedDictionary<String, FNode>) {
        self.dict = dict
    }
    @objc public class func dictionary(with comparator: Comparator) -> FImmutableSortedDictionary {
        FImmutableSortedDictionary(dict: [:])
    }

    @objc public class func fromDictionary(_ dictionary: [String : FNode], withComparator comparator: Comparator) -> FImmutableSortedDictionary {
        var dict = OrderedDictionary(uncheckedUniqueKeys: dictionary.keys, values: dictionary.values)
        dict.sort { a, b in
            FUtilitiesSwift.compareKey(a.key, b.key) == .orderedAscending
        }
        return FImmutableSortedDictionary(dict: dict)
    }
}

//@objc public class FImmutableSortedSet: NSObject {
//    var set: OrderedSet<AnyHashable>
//    let comparator: Comparator?
//
//    @objc public override init() {
//        self.set = []
//        self.comparator = nil
//        super.init()
//    }
//    init(set: OrderedSet<AnyHashable>, comparator: Comparator?) {
//        self.set = set
//        self.comparator = comparator
//        super.init()
//    }
//    @objc public class func setWithKeysFromDictionary(_ dictionary: Dictionary<AnyHashable, Any>, comparator: @escaping Comparator) -> FImmutableSortedSet {
//        var set = OrderedSet(dictionary.keys.map { $0 as AnyHashable })
//        set.sort { a, b in
//            comparator(a, b) == .orderedAscending
//        }
//        return FImmutableSortedSet(set: set, comparator: comparator)
//    }
//    @objc public func removeObject(_ object: AnyHashable) -> FImmutableSortedSet {
//        set.remove(object)
//        return FImmutableSortedSet(set: set, comparator: comparator)
//    }
//    @objc public func addObject(_ object: AnyHashable) -> FImmutableSortedSet {
//        set.append(object)
//        if let c = comparator {
//            set.sort { a, b in
//                c(a, b) == .orderedAscending
//            }
//        }
//        return FImmutableSortedSet(set: set, comparator: comparator)
//    }
//    
//    @objc public func firstObject() -> AnyHashable? {
//        set.first
//    }
//    @objc public func lastObject() -> AnyHashable? {
//        set.last
//    }
//
//    @objc public func predecessorEntry(_ entry: AnyHashable) -> AnyHashable? {
//        guard let index = set.firstIndex(of: entry), index > 0 else {
//            return nil
//        }
//        return set.elements[index - 1]
//    }
//
//    @objc public func enumerateObjects(_ block: (Any, UnsafeMutablePointer<ObjCBool>) -> Void) {
//        var stop = ObjCBool(booleanLiteral: false)
//        for key in set {
//            block(key, &stop)
//            if stop.boolValue {
//                break
//            }
//        }
//    }
//
//    @objc public func enumerateObjectsReverse(_ reverse: Bool, usingBlock block: @escaping (Any, UnsafeMutablePointer<ObjCBool>) -> Void) {
//        var stop = ObjCBool(booleanLiteral: false)
//        if reverse {
//            for key in set.reversed() {
//                block(key, &stop)
//                if stop.boolValue {
//                    break
//                }
//            }
//        } else {
//            for key in set {
//                block(key, &stop)
//                if stop.boolValue {
//                    break
//                }
//            }
//        }
//    }
//
//    @objc public func objectEnumerator() -> NSEnumerator {
//        ObjectEnumerator(iterator: set.makeIterator())
//    }
//}

class ObjectEnumerator: NSEnumerator {
    var iterator: IndexingIterator<(OrderedSet<FNamedNode>)>
    init(iterator: IndexingIterator<(OrderedSet<FNamedNode>)>) {
        self.iterator = iterator
    }

    override func nextObject() -> Any? {
        iterator.next()
    }

}
