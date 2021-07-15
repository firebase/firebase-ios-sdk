//
// Copyright 2021 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

// MARK: This file is used to evaluate the experience of using Firebase APIs in Swift.

import Foundation

import FirebaseCore
import FirebaseDatabase

final class DatabaseAPITests {
  func usage() {
    // MARK: - Database

    // Retrieve Database Instance
    _ = Database.database() as Database
    _ = Database.database(url: "url" as String) as Database
    if let app = FirebaseApp.app() {
      _ = Database.database(app: app as FirebaseApp, url: "url" as String) as Database
      _ = Database.database(app: app as FirebaseApp) as Database
    }
    let instance = Database.database() as Database
    // Retrieve FirebaseApp
    _ = instance.app as FirebaseApp?
    // Retrieve DatabaseReference
    _ = instance.reference() as DatabaseReference
    _ = instance.reference(withPath: "path" as String) as DatabaseReference
    _ = instance.reference(fromURL: "url" as String) as DatabaseReference
    // Instance methods
    instance.purgeOutstandingWrites()
    instance.goOffline()
    instance.goOnline()
    instance.useEmulator(withHost: "host" as String, port: 0 as Int)
    // Instance members
    _ = instance.isPersistenceEnabled as Bool
    _ = instance.persistenceCacheSizeBytes as UInt
    _ = instance.callbackQueue as DispatchQueue
    // Class methods
    Database.setLoggingEnabled(true as Bool)
    _ = Database.sdkVersion() as String

    // MARK: - DatabaseQuery

    let _: DatabaseHandle = 0 as UInt
    let databaseQuery = DatabaseQuery() as DatabaseQuery
    // Observe for data
    _ = databaseQuery.observe(DataEventType.value, with: { (dataSnapshot: DataSnapshot) in
      // ...
    }) as DatabaseHandle
    _ = databaseQuery.observe(
      DataEventType.childAdded,
      andPreviousSiblingKeyWith: { (dataSnaphot: DataSnapshot, optionalString: String?) in
        // ...
      }
    ) as DatabaseHandle
    _ = databaseQuery.observe(DataEventType.childChanged, with: { (dataSnaphot: DataSnapshot) in
      // ...
    }, withCancel: { (error: Error) in
      // ...
    }) as DatabaseHandle
    _ = databaseQuery.observe(
      DataEventType.childMoved,
      andPreviousSiblingKeyWith: { (dataSnapshot: DataSnapshot, optionalString: String?) in
        // ...
      },
      withCancel: { (error: Error) in
        // ...
      }
    ) as DatabaseHandle
    // Get data
    databaseQuery.getData { (optionalError: Error?, dataSnapshot: DataSnapshot) in
      // ...
    }
    #if swift(>=5.5)
      if #available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *) {
        // async/await is a Swift 5.5+ feature available on iOS 15+
        async {
          do {
            _ = try await databaseQuery.getData() as DataSnapshot
          } catch {
            // ...
          }
        }
      }
    #endif // swift(>=5.5)
    // Observe Single Event
    databaseQuery
      .observeSingleEvent(of: DataEventType.childRemoved) { (dataSnapshot: DataSnapshot) in
        // ...
      }
    databaseQuery
      .observeSingleEvent(of: DataEventType
        .value) { (dataSnapshot: DataSnapshot, optionalString: String?) in
        // ...
      }
    #if swift(>=5.5)
      if #available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *) {
        // async/await is a Swift 5.5+ feature available on iOS 15+
        async {
          do {
            _ = try await databaseQuery
              .observeSingleEventAndPreviousSiblingKey(of: DataEventType
                .childAdded) as (DataSnapshot,
                                 String?)
          } catch {
            // ...
          }
        }
      }
    #endif // swift(>=5.5)
    databaseQuery
      .observeSingleEvent(of: DataEventType.childRemoved) { (dataSnapshot: DataSnapshot) in
        // ...
      } withCancel: { (error: Error) in
        // ...
      }
    databaseQuery
      .observeSingleEvent(of: DataEventType
        .childChanged) { (dataSnapshot: DataSnapshot, optionalString: String?) in
        // ...
      } withCancel: { (error: Error) in
        // ...
      }
    // Remove Observers
    databaseQuery.removeObserver(withHandle: 0 as UInt)
    databaseQuery.removeAllObservers()
    // Keep Synced
    databaseQuery.keepSynced(false as Bool)
    // Limited Views of Data
    _ = databaseQuery.queryLimited(toFirst: 1 as UInt) as DatabaseQuery
    _ = databaseQuery.queryLimited(toLast: 2 as UInt) as DatabaseQuery
    _ = databaseQuery.queryOrdered(byChild: "child") as DatabaseQuery
    _ = databaseQuery.queryOrderedByKey() as DatabaseQuery
    _ = databaseQuery.queryOrderedByValue() as DatabaseQuery
    _ = databaseQuery.queryOrderedByPriority() as DatabaseQuery
    _ = databaseQuery.queryStarting(atValue: "value" as Any?) as DatabaseQuery
    _ = databaseQuery.queryStarting(
      atValue: "value" as Any?,
      childKey: "key" as String?
    ) as DatabaseQuery
    _ = databaseQuery.queryStarting(afterValue: "value" as Any?) as DatabaseQuery
    _ = databaseQuery.queryStarting(
      afterValue: "value" as Any?,
      childKey: "key" as String?
    ) as DatabaseQuery
    _ = databaseQuery.queryEnding(atValue: "value" as Any?) as DatabaseQuery
    _ = databaseQuery.queryEnding(beforeValue: "value" as Any?) as DatabaseQuery
    _ = databaseQuery.queryEnding(
      beforeValue: "value" as Any?,
      childKey: "key" as String?
    ) as DatabaseQuery
    _ = databaseQuery.queryEqual(toValue: "value" as Any?) as DatabaseQuery
    _ = databaseQuery.queryEqual(
      toValue: "value" as Any?,
      childKey: "key" as String?
    ) as DatabaseQuery
    // Retrieve DatabaseReference Instance
    _ = databaseQuery.ref as DatabaseReference
  }
}
