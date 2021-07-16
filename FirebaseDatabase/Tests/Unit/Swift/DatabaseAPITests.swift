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
    databaseQuery.removeObserver(withHandle: 0 as DatabaseHandle)
    databaseQuery.removeAllObservers()

    // Keep Synced
    databaseQuery.keepSynced(false as Bool)

    // Limited Views of Data
    _ = databaseQuery.queryLimited(toFirst: 1 as DatabaseHandle) as DatabaseQuery
    _ = databaseQuery.queryLimited(toLast: 2 as DatabaseHandle) as DatabaseQuery
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

    // MARK: - DatabaseReference

    let databaseReference = DatabaseReference() as DatabaseReference

    // Retreive Child DatabaseReference
    _ = databaseReference.child("path" as String) as DatabaseReference
    _ = databaseReference.childByAutoId() as DatabaseReference

    // Set value
    databaseReference.setValue("value" as Any?)
    databaseReference
      .setValue("value" as Any?) { (optionalError: Error?, databaseReference: DatabaseReference) in
        // ...
      }
    #if swift(>=5.5)
      if #available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *) {
        // async/await is a Swift 5.5+ feature available on iOS 15+
        async {
          do {
            _ = try await databaseReference.setValue("value" as Any?) as DatabaseReference
          } catch {
            // ...
          }
        }
      }
    #endif // swift(>=5.5)
    databaseReference.setValue("value" as Any?, andPriority: "priority" as Any?)
    databaseReference
      .setValue("value" as Any?,
                andPriority: "priority" as Any?) { (
        optionalError: Error?,
        databaseReference: DatabaseReference
      ) in
      // ...
      }
    #if swift(>=5.5)
      if #available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *) {
        // async/await is a Swift 5.5+ feature available on iOS 15+
        async {
          do {
            _ = try await databaseReference.setValue(
              "value" as Any?,
              andPriority: "priority" as Any?
            ) as DatabaseReference
          } catch {
            // ...
          }
        }
      }
    #endif // swift(>=5.5)

    // Remove value
    databaseReference.removeValue()
    databaseReference.removeValue { (optionalError: Error?, databaseReference: DatabaseReference) in
      // ...
    }
    #if swift(>=5.5)
      if #available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *) {
        // async/await is a Swift 5.5+ feature available on iOS 15+
        async {
          do {
            _ = try await databaseReference.removeValue() as DatabaseReference
          } catch {
            // ...
          }
        }
      }
    #endif // swift(>=5.5)

    // Set priority
    databaseReference.setPriority("priority" as Any?)
    databaseReference
      .setPriority("priority" as Any?) { (
        optionalError: Error?,
        databaseReference: DatabaseReference
      ) in
      // ...
      }
    #if swift(>=5.5)
      if #available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *) {
        // async/await is a Swift 5.5+ feature available on iOS 15+
        async {
          do {
            _ = try await databaseReference.setPriority("priority" as Any?) as DatabaseReference
          } catch {
            // ...
          }
        }
      }
    #endif // swift(>=5.5)

    // Update child values
    databaseReference.updateChildValues([AnyHashable: Any]())
    databaseReference
      .updateChildValues([AnyHashable: Any]()) { (
        optionalError: Error?,
        databaseReference: DatabaseReference
      ) in
      // ...
      }
    #if swift(>=5.5)
      if #available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *) {
        // async/await is a Swift 5.5+ feature available on iOS 15+
        async {
          do {
            _ = try await databaseReference
              .updateChildValues([AnyHashable: Any]()) as DatabaseReference
          } catch {
            // ...
          }
        }
      }
    #endif // swift(>=5.5)

    // Observe for data
    _ = databaseReference.observe(DataEventType.value) { (dataSnaphot: DataSnapshot) in
      // ...
    } as DatabaseHandle
    _ = databaseReference
      .observe(DataEventType.childChanged) { (dataSnaphot: DataSnapshot, optionalString: String?) in
        // ...
      } as DatabaseHandle
    _ = databaseReference.observe(
      DataEventType.childRemoved,
      with: { (dataSnapshot: DataSnapshot) in
        // ...
      },
      withCancel: { (error: Error) in
        // ...
      }
    ) as DatabaseHandle
    _ = databaseReference.observe(
      DataEventType.childChanged,
      andPreviousSiblingKeyWith: { (dataSnapshot: DataSnapshot, optionalString: String?) in
        // ...
      },
      withCancel: { (error: Error) in
        // ...
      }
    ) as DatabaseHandle

    // Observe Single Event
    databaseReference
      .observeSingleEvent(of: DataEventType.childAdded) { (dataSnapshot: DataSnapshot) in
        // ...
      }
    databaseReference
      .observeSingleEvent(of: DataEventType
        .childMoved) { (dataSnapshot: DataSnapshot, optionalString: String?) in
        // ...
      }
    #if swift(>=5.5)
      if #available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *) {
        // async/await is a Swift 5.5+ feature available on iOS 15+
        async {
          do {
            _ = try await databaseReference
              .observeSingleEventAndPreviousSiblingKey(of: DataEventType.value) as (DataSnapshot,
                                                                                    String?)
          } catch {
            // ...
          }
        }
      }
    #endif // swift(>=5.5)
    databaseReference
      .observeSingleEvent(of: DataEventType.childChanged) { (dataSnapshot: DataSnapshot) in
        // ...
      } withCancel: { (error: Error) in
        // ...
      }
    databaseReference
      .observeSingleEvent(of: DataEventType
        .childMoved) { (dataSnapshot: DataSnapshot, optionalString: String?) in
        // ...
      } withCancel: { (error: Error) in
        // ...
      }

    // Get data
    databaseReference.getData { (optionalError: Error?, dataSnapshot: DataSnapshot) in
      // ...
    }
    #if swift(>=5.5)
      if #available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *) {
        // async/await is a Swift 5.5+ feature available on iOS 15+
        async {
          do {
            _ = try await databaseReference.getData() as DataSnapshot
          } catch {
            // ...
          }
        }
      }
    #endif // swift(>=5.5)

    // Remove Observers
    databaseReference.removeObserver(withHandle: 0 as DatabaseHandle)
    databaseReference.removeAllObservers()

    // Keep Synced
    databaseReference.keepSynced(true as Bool)

    // Limited Views of Data
    _ = databaseReference.queryLimited(toFirst: 0 as DatabaseHandle) as DatabaseQuery
    _ = databaseReference.queryLimited(toLast: 1 as DatabaseHandle) as DatabaseQuery
    _ = databaseReference.queryOrdered(byChild: "key" as String) as DatabaseQuery
    _ = databaseReference.queryOrderedByKey() as DatabaseQuery
    _ = databaseReference.queryOrderedByPriority() as DatabaseQuery
    _ = databaseReference.queryStarting(atValue: "value" as Any?) as DatabaseQuery
    _ = databaseReference.queryStarting(
      atValue: "value" as Any?,
      childKey: "key" as String?
    ) as DatabaseQuery
    _ = databaseReference.queryStarting(afterValue: "value" as Any?) as DatabaseQuery
    _ = databaseReference.queryStarting(
      afterValue: "value" as Any?,
      childKey: "key" as String?
    ) as DatabaseQuery
    _ = databaseReference.queryEnding(atValue: "value" as Any?) as DatabaseQuery
    _ = databaseReference.queryEnding(
      atValue: "value" as Any?,
      childKey: "key" as String?
    ) as DatabaseQuery
    _ = databaseReference.queryEqual(toValue: "value" as Any?) as DatabaseQuery
    _ = databaseReference.queryEqual(
      toValue: "value" as Any?,
      childKey: "key" as String?
    ) as DatabaseQuery

    // onDisconnectSetValue
    databaseReference.onDisconnectSetValue("value" as Any?)
    databaseReference
      .onDisconnectSetValue("value" as Any?) { (
        optionalError: Error?,
        databaseReference: DatabaseReference
      ) in
      // ...
      }
    #if swift(>=5.5)
      if #available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *) {
        // async/await is a Swift 5.5+ feature available on iOS 15+
        async {
          do {
            _ = try await databaseReference
              .onDisconnectSetValue("value" as Any?) as DatabaseReference
          } catch {
            // ...
          }
        }
      }
    #endif // swift(>=5.5)
    databaseReference.onDisconnectSetValue("value" as Any?, andPriority: "priority" as Any)
    databaseReference
      .onDisconnectSetValue("value" as Any?,
                            andPriority: "priority" as Any?) { (
        optionalError: Error?,
        databaseReference: DatabaseReference
      ) in
      // ...
      }
    #if swift(>=5.5)
      if #available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *) {
        // async/await is a Swift 5.5+ feature available on iOS 15+
        async {
          do {
            _ = try await databaseReference.onDisconnectSetValue(
              "value" as Any?,
              andPriority: "priority" as Any?
            ) as DatabaseReference
          } catch {
            // ...
          }
        }
      }
    #endif // swift(>=5.5)

    // onDisconnectRemoveValue
    databaseReference.onDisconnectRemoveValue()
    databaseReference
      .onDisconnectRemoveValue { (optionalError: Error?, databaseReference: DatabaseReference) in
        // ...
      }
    #if swift(>=5.5)
      if #available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *) {
        // async/await is a Swift 5.5+ feature available on iOS 15+
        async {
          do {
            _ = try await databaseReference.onDisconnectRemoveValue() as DatabaseReference
          } catch {
            // ...
          }
        }
      }
    #endif // swift(>=5.5)

    // onDisconnectUpdateChildValues
    databaseReference.onDisconnectUpdateChildValues([AnyHashable: Any]())
    databaseReference
      .onDisconnectUpdateChildValues([AnyHashable: Any]()) { (
        optionalError: Error?,
        databaseReference: DatabaseReference
      ) in
      // ...
      }
    #if swift(>=5.5)
      if #available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *) {
        // async/await is a Swift 5.5+ feature available on iOS 15+
        async {
          do {
            _ = try await databaseReference
              .onDisconnectUpdateChildValues([AnyHashable: Any]()) as DatabaseReference
          } catch {
            // ...
          }
        }
      }
    #endif // swift(>=5.5)

    // cancelDisconnectOperations
    databaseReference.cancelDisconnectOperations()
    databaseReference
      .cancelDisconnectOperations { (optionalError: Error?, databaseReference: DatabaseReference) in
        // ...
      }
    #if swift(>=5.5)
      if #available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *) {
        // async/await is a Swift 5.5+ feature available on iOS 15+
        async {
          do {
            _ = try await databaseReference.cancelDisconnectOperations() as DatabaseReference
          } catch {
            // ...
          }
        }
      }
    #endif // swift(>=5.5)

    // runTransactionBlock
    databaseReference.runTransactionBlock { (mutableData: MutableData) in
      TransactionResult()
    }
    databaseReference.runTransactionBlock { (mutableData: MutableData) in
      TransactionResult()
    } andCompletionBlock: { (optionalError: Error?, bool: Bool, optinalDataSnapshot: DataSnapshot?) in
      // ...
    }
    #if swift(>=5.5)
      if #available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *) {
        // async/await is a Swift 5.5+ feature available on iOS 15+
        async {
          do {
            _ = try await databaseReference.runTransactionBlock { (mutableData: MutableData) in
              TransactionResult()
            } as (Bool, DataSnapshot)
          } catch {
            // ...
          }
        }
      }
    #endif // swift(>=5.5)
    databaseReference.runTransactionBlock({ (mutableData: MutableData) in
                                            TransactionResult()
                                          },
                                          andCompletionBlock: { (
                                            optionalError: Error?,
                                            bool: Bool,
                                            optionalDataSnapshot: DataSnapshot?
                                          ) in
                                          // ...
                                          }, withLocalEvents: true as Bool)

    // description
    _ = databaseReference.description() as String

    // Class methods
    DatabaseReference.goOffline()
    DatabaseReference.goOnline()

    // Instance properties
    _ = databaseReference.parent as DatabaseReference?
    _ = databaseReference.root as DatabaseReference
    _ = databaseReference.key as String?
    _ = databaseReference.url as String
    _ = databaseReference.database as Database

    // MARK: - DataEventType

    let dataEventType = DataEventType(rawValue: 0)
    switch dataEventType {
    case .childAdded:
      break
    case .childRemoved:
      break
    case .childChanged:
      break
    case .childMoved:
      break
    case .value:
      break
    case .none:
      break
    case .some:
      break
    }

    // MARK: - DataSnapshot

    let dataSnapshot = DataSnapshot()

    // Navigating and inspecting a snapshot
    _ = dataSnapshot.childSnapshot(forPath: "path" as String) as DataSnapshot
    _ = dataSnapshot.hasChild("path" as String) as Bool
    _ = dataSnapshot.hasChildren() as Bool
    _ = dataSnapshot.exists() as Bool

    // Data export
    _ = dataSnapshot.valueInExportFormat() as Any?

    // Properties
    _ = dataSnapshot.value as Any?
    _ = dataSnapshot.childrenCount as UInt
    _ = dataSnapshot.ref as DatabaseReference
    _ = dataSnapshot.key as String
    _ = dataSnapshot.children as NSEnumerator
    _ = dataSnapshot.priority as Any?

    // MARK: - MutableData

    let mutableData = MutableData()

    // Inspecting and navigating the data
    _ = mutableData.hasChildren() as Bool
    _ = mutableData.hasChild(atPath: "path" as String) as Bool
    _ = mutableData.childData(byAppendingPath: "path" as String) as MutableData

    // Properties
    _ = mutableData.value as Any?
    _ = mutableData.priority as Any?
    _ = mutableData.childrenCount as UInt
    _ = mutableData.children as NSEnumerator
    _ = mutableData.key as String?

    // MARK: - ServerValue

    _ = ServerValue.timestamp() as [AnyHashable: Any]
    _ = ServerValue.increment(0 as NSNumber) as [AnyHashable: Any]

    // MARK: - TransactionResult

    _ = TransactionResult.success(withValue: MutableData()) as TransactionResult
    _ = TransactionResult.abort() as TransactionResult
  }
}
