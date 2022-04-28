//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 21/04/2022.
//

import Foundation

/**
 * A FIRMutableData instance is populated with data from a Firebase Database
 * location. When you are using runTransactionBlock:, you will be given an
 * instance containing the current data at that location. Your block will be
 * responsible for updating that instance to the data you wish to save at that
 * location, and then returning using [FIRTransactionResult successWithValue:].
 *
 * To modify the data, set its value property to any of the native types support
 * by Firebase Database:
 *
 * + NSNumber (includes BOOL)
 * + NSDictionary
 * + NSArray
 * + NSString
 * + nil / NSNull to remove the data
 *
 * Note that changes made to a child FIRMutableData instance will be visible to
 * the parent.
 */

@objc(FIRMutableData) public class MutableData: NSObject {

    // MARK: - Inspecting and navigating the data

    /**
     * Returns boolean indicating whether this mutable data has children.
     *
     * @return YES if this data contains child nodes.
     */
    @objc public var hasChildren: Bool {
        let node = data.getNode(prefixPath)
        guard let childrenNode = node as? FChildrenNode else {
            return false
        }
        return !childrenNode.isEmpty
    }

    /**
     * Indicates whether this mutable data has a child at the given path.
     *
     * @param path A path string, consisting either of a single segment, like
     * 'child', or multiple segments, 'a/deeper/child'
     * @return YES if this data contains a child at the specified relative path
     */
    @objc public func hasChildAtPath(_ path: String) -> Bool {
        let node = data.getNode(prefixPath)
        let childPath = FPath(with: path)
        return !node.getChild(childPath).isEmpty
    }

    /**
     * Used to obtain a FIRMutableData instance that encapsulates the data at the
     * given relative path. Note that changes made to the child will be visible to
     * the parent.
     *
     * @param path A path string, consisting either of a single segment, like
     * 'child', or multiple segments, 'a/deeper/child'
     * @return A FIRMutableData instance containing the data at the given path
     */
    @objc public func childDataByAppendingPath(_ path: String) -> MutableData {
        let wholePath = prefixPath.child(fromString: path)
        return MutableData(prefixPath: wholePath, andSnapshotHolder: data)
    }

    internal var parent: MutableData? {
        guard let path = prefixPath.parent() else {
            return nil
        }
        return MutableData(prefixPath: path, andSnapshotHolder: data)
    }

    @objc public func setValue(_ value: Any?) {
        let node = FSnapshotUtilitiesSwift.nodeFrom(value,
                                                    withValidationFrom: "setValue:")
        data.updateSnapshot(prefixPath, withNewSnapshot: node)
    }

    @objc public func setPriority(_ priority: Any) {
        var node = data.getNode(prefixPath)
        let pri = FSnapshotUtilitiesSwift.nodeFrom(priority)
        node = node.updatePriority(pri)
        data.updateSnapshot(prefixPath, withNewSnapshot: node)
    }


    // MARK: - Properties

    /**
     * To modify the data contained by this instance of FIRMutableData, set this to
     * any of the native types supported by Firebase Database:
     *
     * + NSNumber (includes BOOL)
     * + NSDictionary
     * + NSArray
     * + NSString
     * + nil / NSNull to remove the data
     *
     * Note that setting this value will override the priority at this location.
     *
     * @return The current data at this location as a native object
     */
    @objc public var value: Any {
        data.getNode(prefixPath).val()
    }

    /**
     * Set this property to update the priority of the data at this location. Can be
     * set to the following types:
     *
     * + NSNumber
     * + NSString
     * + nil / NSNull to remove the priority
     *
     * @return The priority of the data at this location
     */
    @objc public var priority: Any {
        data.getNode(prefixPath).getPriority().val()
    }

    /**
     * @return The number of child nodes at this location
     */
    @objc public var childrenCount: Int {
        data.getNode(prefixPath).numChildren()
    }

    /**
     * Used to iterate over the children at this location. You can use the native
     * for .. in syntax:
     *
     * for (FIRMutableData* child in data.children) {
     *     ...
     * }
     *
     * Note that this enumerator operates on an immutable copy of the child list.
     * So, you can modify the instance during iteration, but the new additions will
     * not be visible until you get a new enumerator.
     */
    @objc public var children: NSEnumerator {
        let indexedNode = FIndexedNode(node: nodeValue)

        return FTransformedEnumerator(enumerator: indexedNode.childEnumerator()) { item in
            guard let node = item as? FNamedNode else { return item }
            let childPath = self.prefixPath.child(fromString: node.name)
            let childData = MutableData(prefixPath: childPath, andSnapshotHolder: self.data)
            return childData
        }
    }

    /**
     * @return The key name of this node, or nil if it is the top-most location
     */
    @objc public var key: String? {
        prefixPath.getBack()
    }

    internal var nodeValue: FNode {
        data.getNode(prefixPath)
    }

    internal let data: FSnapshotHolder
    internal let prefixPath: FPath

    @objc public convenience init(node: FNode) {
        let holder = FSnapshotHolder()
        let path = FPath.empty
        holder.updateSnapshot(path, withNewSnapshot: node)
        self.init(prefixPath: path, andSnapshotHolder: holder)
    }

    internal init(prefixPath: FPath, andSnapshotHolder snapshotHolder: FSnapshotHolder) {
        self.prefixPath = prefixPath
        self.data = snapshotHolder
    }
    public override var description: String {
        if let key = key {
            return "FIRMutableData (\(key)) \(value)"
        } else {
            return "FIRMutableData (top-most transaction) \(value)"
        }

    }
}
