//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 28/04/2022.
//

import Foundation

/**
 * Placeholder values you may write into Firebase Database as a value or
 * priority that will automatically be populated by the Firebase Database
 * server.
 */
@objc(FIRServerValue) public class ServerValue: NSObject {

    /**
     * Placeholder value for the number of milliseconds since the Unix epoch
     */
    @objc public static var timestamp: [String: Any] = [".sv": "timestamp"]

    /**
     * Returns a placeholder value that can be used to atomically increment the
     * current database value by the provided delta.
     *
     * The delta must be a long or double value. If the current value is not an
     * integer or double, or if the data does not yet exist, the transformation will
     * set the data to the delta value. If either of the delta value or the existing
     * data are doubles, both values will be interpreted as doubles. Double
     * arithmetic and representation of double values follow IEEE 754 semantics. If
     * there is positive/negative integer overflow, the sum is calculated as a
     * double.
     *
     * @param delta the amount to modify the current value atomically.
     * @return a placeholder value for modifying data atomically server-side.
     */
    @objc public class func increment(_ delta: NSNumber) -> [String: Any] {
        [".sv": ["increment": delta]]
    }
}
