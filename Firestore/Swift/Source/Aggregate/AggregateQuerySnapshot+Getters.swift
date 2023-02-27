/*
 * Copyright 2019 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation
import FirebaseFirestore

public extension AggregateQuerySnapshot {
    /// Gets the aggregation result for the specified aggregation, coercing te result to a Double.
    ///
    /// See the `AggregateField` class for the expected aggregation result values and types.
    ///
    /// - Parameters:
    ///   - aggregation: An instance of `AggregateField` that specifies which aggregation result to return.
    /// - Returns: Returns the aggregation result coerced to a `Double`.
    /// - Throws: 'Error' if the value is non-numeric and cannot be coerced to a `Double`.
    /// - Throws: InvalidArgument exception if the aggregation was not requested in the `AggregateQuery`. This is unrecoverable.
    func getDouble(_ aggregation: AggregateField) throws -> Double {
        // TODO(sumavg) implement
        guard let number = self.get(aggregation) as? NSNumber else {
            throw FirestoreError.incompatibleType("Unable to represent the result as a Double.")
        }
        
        return number.doubleValue
    }
    
    /// Gets the aggregation result for the specified aggregation, coercing te result to an Int64.
    ///
    /// See the `AggregateField` class for the expected aggregration result values and types.
    ///
    /// - Parameters:
    ///   - aggregation: An instance of `AggregateField` that specifies which aggregation result to return.
    /// - Returns: Returns the aggregation result coerced to an `Int64`.
    /// - Throws: 'Error' if the value is non-numeric and cannot be coerced to an `Int64`.
    /// - Throws: InvalidArgument exception if the aggregation was not requested in the `AggregateQuery`. This is unrecoverable.
    func getLong(_ aggregation: AggregateField) throws -> Int64 {
        // TODO(sumavg) implement
        guard let number = self.get(aggregation) as? NSNumber else {
            throw FirestoreError.incompatibleType("Unable to represent the result as an Int64.")
        }

        return number.int64Value
    }
}

// TODO(sumavg) implement or use an existing error type
public enum FirestoreError: Error {
  case incompatibleType(String)
}
