//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 28/10/2021.
//

import Foundation

@objc(FIRDataEventType) public enum DataEventType: Int {
    /// A new child node is added to a location.
    @objc(FIRDataEventTypeChildAdded) case childAdded
    /// A child node is removed from a location.
    @objc(FIRDataEventTypeChildRemoved) case childRemoved
    /// A child node at a location changes.
    @objc(FIRDataEventTypeChildChanged) case childChanged
    /// A child node moves relative to the other child nodes at a location.
    @objc(FIRDataEventTypeChildMoved) case childMoved
    /// Any data changes at a location or, recursively, at any child node.
    @objc(FIRDataEventTypeValue) case value
}
