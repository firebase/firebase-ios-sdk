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

// MARK: This file is used to evaluate the experience of using the Firebase Database APIs in Swift.

import Foundation

import FirebaseCore
import FirebaseDatabase

final class DatabaseAPITests {
  func usage() {
    // MARK: - Database

    var url = "url"
    let path = "path"
    let host = "host"
    let port = 0
    let yes = true

    // Retrieve Database Instance
    var database: Database = Database.database()

    database = Database.database(url: url)

    if let app = FirebaseApp.app() {
      database = Database.database(app: app, url: url)
      database = Database.database(app: app)
    }

    // Retrieve FirebaseApp
    let /* app */ _: FirebaseApp? = database.app

    // Retrieve DatabaseReference
    var databaseReference: DatabaseReference = database.reference()
    databaseReference = database.reference(withPath: path)
    databaseReference = database.reference(fromURL: url)

    // Instance methods
    database.purgeOutstandingWrites()
    database.goOffline()
    database.goOnline()
    database.useEmulator(withHost: host, port: port)

    // Instance members
    let /* isPersistenceEnabled */ _: Bool = database.isPersistenceEnabled
    let /* persistenceCacheSizeBytes */ _: UInt = database.persistenceCacheSizeBytes
    let /* callbackQueue */ _: DispatchQueue = database.callbackQueue

    // Class methods
    Database.setLoggingEnabled(yes)
    let /* sdkVersion */ _: String = Database.sdkVersion()

    // MARK: - DatabaseQuery

    let uint: UInt = 0
    let dataEventType: DataEventType = .value
    let child = "child"
    let childKey: String? = "key"
    let value: Any? = "value"
    let priority: Any? = "priority"

    var databaseHandle: DatabaseHandle = uint
    var databaseQuery: DatabaseQuery = DatabaseQuery()

    // Observe for data

    // observe(_ eventType:with block:)
    databaseHandle = databaseQuery.observe(dataEventType) { dataSnapshot in
      let /* dataSnapshot */ _: DataSnapshot = dataSnapshot
    }

    // observe(_ eventType:andPreviousSiblingKeyWith block:)
    databaseHandle = databaseQuery.observe(dataEventType) { dataSnapshot, optionalString in
      let /* dataSnapshot */ _: DataSnapshot = dataSnapshot
      let /* optionalString */ _: String? = optionalString
    }

    // observe(_ eventType:with block:withCancel cancelBlock:)
    databaseHandle = databaseQuery.observe(dataEventType) { dataSnapshot in
      let /* dataSnapshot */ _: DataSnapshot = dataSnapshot
    } withCancel: { error in
      let /* error */ _: Error = error
    }

    // observe(_ eventType:andPreviousSiblingKeyWith block:withCancel cancelBlock:)
    databaseHandle = databaseQuery.observe(dataEventType) { dataSnapshot, optionalString in
      let /* dataSnapshot */ _: DataSnapshot = dataSnapshot
      let /* optionalString */ _: String? = optionalString
    } withCancel: { error in
      let /* error */ _: Error = error
    }

    // Get data

    // getData(completion block:)
    databaseQuery.getData { optionalError, dataSnapshot in
      let /* optionalError */ _: Error? = optionalError
      let /* dataSnapshot */ _: DataSnapshot = dataSnapshot
    }

    #if compiler(>=5.5) && canImport(_Concurrency)
      if #available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *) {
        // async/await is a Swift 5.5+ feature available on iOS 15+
        Task {
          do {
            let /* dataSnapshot */ _: DataSnapshot = try await DatabaseQuery().getData()
          } catch {
            // ...
          }
        }
      }
    #endif // swift(>=5.5)

    // Observe Single Event

    // observeSingleEvent(of eventType:with block:)
    databaseQuery.observeSingleEvent(of: dataEventType) { dataSnapshot in
      let /* dataSnapshot */ _: DataSnapshot = dataSnapshot
    }

    // observeSingleEvent(of eventType:andPreviousSiblingKeyWith block:)
    databaseQuery.observeSingleEvent(of: dataEventType) { dataSnapshot, optionalString in
      let /* dataSnapshot */ _: DataSnapshot = dataSnapshot
      let /* optionalString */ _: String? = optionalString
    }

    #if compiler(>=5.5) && canImport(_Concurrency)
      if #available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *) {
        // async/await is a Swift 5.5+ feature available on iOS 15+
        Task {
          // observeSingleEvent(of eventType:)
          let _: (DataSnapshot, String?) = await DatabaseQuery()
            .observeSingleEventAndPreviousSiblingKey(of: dataEventType)
        }
      }
    #endif // swift(>=5.5)

    // observeSingleEvent(of eventType:with block:withCancel cancelBlock:)
    databaseQuery.observeSingleEvent(of: dataEventType) { dataSnapshot in
      let /* dataSnapshot */ _: DataSnapshot = dataSnapshot
    } withCancel: { error in
      let /* error */ _: Error = error
    }

    // observeSingleEvent(of eventType:andPreviousSiblingKeyWith block:withCancel cancelBlock:)
    databaseQuery.observeSingleEvent(of: dataEventType) { dataSnapshot, optionalString in
      let /* dataSnapshot */ _: DataSnapshot = dataSnapshot
      let /* optionalString */ _: String? = optionalString
    } withCancel: { error in
      let /* error */ _: Error = error
    }

    // Remove Observers
    databaseQuery.removeObserver(withHandle: databaseHandle)
    databaseQuery.removeAllObservers()

    // Keep Synced
    databaseQuery.keepSynced(yes)

    // Limited Views of Data
    databaseQuery = databaseQuery.queryLimited(toFirst: databaseHandle)
    databaseQuery = databaseQuery.queryLimited(toLast: databaseHandle)
    databaseQuery = databaseQuery.queryOrdered(byChild: child)
    databaseQuery = databaseQuery.queryOrderedByKey()
    databaseQuery = databaseQuery.queryOrderedByValue()
    databaseQuery = databaseQuery.queryOrderedByPriority()
    databaseQuery = databaseQuery.queryStarting(atValue: value)
    databaseQuery = databaseQuery.queryStarting(atValue: value, childKey: childKey)
    databaseQuery = databaseQuery.queryStarting(afterValue: value)
    databaseQuery = databaseQuery.queryStarting(afterValue: value, childKey: childKey)
    databaseQuery = databaseQuery.queryEnding(atValue: value)
    databaseQuery = databaseQuery.queryEnding(beforeValue: value)
    databaseQuery = databaseQuery.queryEnding(beforeValue: value, childKey: childKey)
    databaseQuery = databaseQuery.queryEqual(toValue: value)
    databaseQuery = databaseQuery.queryEqual(toValue: value, childKey: childKey)

    // Retrieve DatabaseReference Instance
    databaseReference = databaseQuery.ref

    // MARK: - DatabaseReference

    let priorityAny: Any = "priority"
    let values = [AnyHashable: Any]()
    var transactionResult = TransactionResult()

    // Retreive Child DatabaseReference
    databaseReference = databaseReference.child(child)
    databaseReference = databaseReference.childByAutoId()

    // Set value
    databaseReference.setValue(value)

    // setValue(_ value:withCompletionBlock block:)
    databaseReference.setValue(value) { optionalError, databaseReference in
      let /* optionalError */ _: Error? = optionalError
      let /* databaseReference */ _: DatabaseReference = databaseReference
    }

    #if compiler(>=5.5) && canImport(_Concurrency)
      if #available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *) {
        // async/await is a Swift 5.5+ feature available on iOS 15+
        Task {
          do {
            // setValue(_ value:)
            let /* ref */ _: DatabaseReference = try await DatabaseReference().setValue(value)
          } catch {
            // ...
          }
        }
      }
    #endif // swift(>=5.5)

    databaseReference.setValue(value, andPriority: priority)

    // setValue(_ value:andPriority priority:withCompletionBlock block:)
    databaseReference.setValue(value, andPriority: priority) { optionalError, databaseReference in
      let /* optionalError */ _: Error? = optionalError
      let /* databaseReference */ _: DatabaseReference = databaseReference
    }

    #if compiler(>=5.5) && canImport(_Concurrency)
      if #available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *) {
        // async/await is a Swift 5.5+ feature available on iOS 15+
        Task {
          do {
            // setValue(_ value:andPriority priority:)
            let /* ref */ _: DatabaseReference = try await DatabaseReference()
              .setValue(value, andPriority: priority)
          } catch {
            // ...
          }
        }
      }
    #endif // swift(>=5.5)

    // Remove value
    databaseReference.removeValue()

    // removeValue(completionBlock block:)
    databaseReference.removeValue { optionalError, databaseReference in
      let /* optionalError */ _: Error? = optionalError
      let /* databaseReference */ _: DatabaseReference = databaseReference
    }

    #if compiler(>=5.5) && canImport(_Concurrency)
      if #available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *) {
        // async/await is a Swift 5.5+ feature available on iOS 15+
        Task {
          do {
            let /* ref */ _: DatabaseReference = try await DatabaseReference().removeValue()
          } catch {
            // ...
          }
        }
      }
    #endif // swift(>=5.5)

    // Set priority
    databaseReference.setPriority(priority)

    // setPriority(_ priority:withCompletionBlock block:)
    databaseReference.setPriority(priority) { optionalError, databaseReference in
      let /* optionalError */ _: Error? = optionalError
      let /* databaseReference */ _: DatabaseReference = databaseReference
    }

    #if compiler(>=5.5) && canImport(_Concurrency)
      if #available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *) {
        // async/await is a Swift 5.5+ feature available on iOS 15+
        Task {
          do {
            // setPriority(_ priority:)
            let /* ref */ _: DatabaseReference = try await DatabaseReference().setPriority(priority)
          } catch {
            // ...
          }
        }
      }
    #endif // swift(>=5.5)

    // Update child values
    databaseReference.updateChildValues(values)

    // updateChildValues(_ values:withCompletionBlock block:)
    databaseReference.updateChildValues(values) { optionalError, databaseReference in
      let /* optionalError */ _: Error? = optionalError
      let /* databaseReference */ _: DatabaseReference = databaseReference
    }

    #if compiler(>=5.5) && canImport(_Concurrency)
      if #available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *) {
        // async/await is a Swift 5.5+ feature available on iOS 15+
        Task {
          do {
            // updateChildValues(_ values:)
            let /* ref */ _: DatabaseReference = try await DatabaseReference()
              .updateChildValues(values)
          } catch {
            // ...
          }
        }
      }
    #endif // swift(>=5.5)

    // Observe for data

    // observe(_ eventType:with block:)
    databaseHandle = databaseReference.observe(dataEventType) { dataSnapshot in
      let /* dataSnapshot */ _: DataSnapshot = dataSnapshot
    }

    // observe(_ eventType:andPreviousSiblingKeyWith block:)
    databaseHandle = databaseReference.observe(dataEventType) { dataSnapshot, optionalString in
      let /* dataSnapshot */ _: DataSnapshot = dataSnapshot
      let /* optionalString */ _: String? = optionalString
    }

    // observe(_ eventType:with block:withCancel cancelBlock:)
    databaseHandle = databaseReference.observe(dataEventType) { dataSnapshot in
      let /* dataSnapshot */ _: DataSnapshot = dataSnapshot
    } withCancel: { error in
      let /* error */ _: Error = error
    }

    // observe(_ eventType:andPreviousSiblingKeyWith block:withCancel cancelBlock:)
    databaseHandle = databaseReference.observe(dataEventType) { dataSnapshot, optionalString in
      let /* dataSnapshot */ _: DataSnapshot = dataSnapshot
      let /* optionalString */ _: String? = optionalString
    } withCancel: { error in
      let /* error */ _: Error = error
    }

    // Observe Single Event

    // observeSingleEvent(of eventType:with block:)
    databaseReference.observeSingleEvent(of: dataEventType) { dataSnapshot in
      let /* dataSnapshot */ _: DataSnapshot = dataSnapshot
    }

    // observeSingleEvent(of eventType:andPreviousSiblingKeyWith block:)
    databaseReference.observeSingleEvent(of: dataEventType) { dataSnapshot, optionalString in
      let /* dataSnapshot */ _: DataSnapshot = dataSnapshot
      let /* optionalString */ _: String? = optionalString
    }

    #if compiler(>=5.5) && canImport(_Concurrency)
      if #available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *) {
        // async/await is a Swift 5.5+ feature available on iOS 15+
        Task {
          // observeSingleEvent(of eventType:)
          let _: (DataSnapshot, String?) = await DatabaseReference()
            .observeSingleEventAndPreviousSiblingKey(of: dataEventType)
        }
      }
    #endif // swift(>=5.5)

    // observeSingleEvent(of eventType:with block:withCancel cancelBlock:)
    databaseReference.observeSingleEvent(of: dataEventType) { dataSnapshot in
      let /* dataSnapshot */ _: DataSnapshot = dataSnapshot
    } withCancel: { error in
      let /* error */ _: Error = error
    }

    // observeSingleEvent(of eventType:andPreviousSiblingKeyWith block:withCancel cancelBlock:)
    databaseReference.observeSingleEvent(of: dataEventType) { dataSnapshot, optionalString in
      let /* dataSnapshot */ _: DataSnapshot = dataSnapshot
      let /* optionalString */ _: String? = optionalString
    } withCancel: { error in
      let /* error */ _: Error = error
    }

    // Get data

    // getData(completion block:)
    databaseReference.getData { optionalError, dataSnapshot in
      let /* optionalError */ _: Error? = optionalError
      let /* dataSnapshot */ _: DataSnapshot = dataSnapshot
    }

    #if compiler(>=5.5) && canImport(_Concurrency)
      if #available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *) {
        // async/await is a Swift 5.5+ feature available on iOS 15+
        Task {
          do {
            let /* dataSnapshot */ _: DataSnapshot = try await DatabaseReference().getData()
          } catch {
            // ...
          }
        }
      }
    #endif // swift(>=5.5)

    // Remove Observers
    databaseReference.removeObserver(withHandle: databaseHandle)
    databaseReference.removeAllObservers()

    // Keep Synced
    databaseReference.keepSynced(yes)

    // Limited Views of Data
    databaseQuery = databaseReference.queryLimited(toFirst: databaseHandle)
    databaseQuery = databaseReference.queryLimited(toLast: databaseHandle)
    databaseQuery = databaseReference.queryOrdered(byChild: child)
    databaseQuery = databaseReference.queryOrderedByKey()
    databaseQuery = databaseReference.queryOrderedByPriority()
    databaseQuery = databaseReference.queryStarting(atValue: value)
    databaseQuery = databaseReference.queryStarting(atValue: value, childKey: childKey)
    databaseQuery = databaseReference.queryStarting(afterValue: value)
    databaseQuery = databaseReference.queryStarting(afterValue: value, childKey: childKey)
    databaseQuery = databaseReference.queryEnding(atValue: value)
    databaseQuery = databaseReference.queryEnding(atValue: value, childKey: childKey)
    databaseQuery = databaseReference.queryEqual(toValue: value)
    databaseQuery = databaseReference.queryEqual(toValue: value, childKey: childKey)

    // onDisconnectSetValue
    databaseReference.onDisconnectSetValue(value)

    // onDisconnectSetValue(_ value:withCompletionBlock block:)
    databaseReference.onDisconnectSetValue(value) { optionalError, databaseReference in
      let /* optionalError */ _: Error? = optionalError
      let /* databaseReference */ _: DatabaseReference = databaseReference
    }

    #if compiler(>=5.5) && canImport(_Concurrency)
      if #available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *) {
        // async/await is a Swift 5.5+ feature available on iOS 15+
        Task {
          do {
            // onDisconnectSetValue(_ value:)
            let /* ref */ _: DatabaseReference = try await DatabaseReference()
              .onDisconnectSetValue(value)
          } catch {
            // ...
          }
        }
      }
    #endif // swift(>=5.5)

    databaseReference.onDisconnectSetValue(value, andPriority: priorityAny)

    // onDisconnectSetValue(_ value:andPriority priority:withCompletionBlock block:)
    databaseReference
      .onDisconnectSetValue(value, andPriority: priority) { optionalError, databaseReference in
        let /* optionalError */ _: Error? = optionalError
        let /* databaseReference */ _: DatabaseReference = databaseReference
      }

    #if compiler(>=5.5) && canImport(_Concurrency)
      if #available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *) {
        // async/await is a Swift 5.5+ feature available on iOS 15+
        Task {
          do {
            // onDisconnectSetValue(_ value:andPriority priority:)
            let /* ref */ _: DatabaseReference = try await DatabaseReference().onDisconnectSetValue(
              value,
              andPriority: priority
            )
          } catch {
            // ...
          }
        }
      }
    #endif // swift(>=5.5)

    // onDisconnectRemoveValue
    databaseReference.onDisconnectRemoveValue()

    // onDisconnectRemoveValue(completionBlock block:)
    databaseReference.onDisconnectRemoveValue { optionalError, databaseReference in
      let /* optionalError */ _: Error? = optionalError
      let /* databaseReference */ _: DatabaseReference = databaseReference
    }

    #if compiler(>=5.5) && canImport(_Concurrency)
      if #available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *) {
        // async/await is a Swift 5.5+ feature available on iOS 15+
        Task {
          do {
            let /* ref */ _: DatabaseReference = try await DatabaseReference()
              .onDisconnectRemoveValue()
          } catch {
            // ...
          }
        }
      }
    #endif // swift(>=5.5)

    // onDisconnectUpdateChildValues
    databaseReference.onDisconnectUpdateChildValues(values)

    // onDisconnectUpdateChildValues(_ values:withCompletionBlock block:)
    databaseReference.onDisconnectUpdateChildValues(values) { optionalError, databaseReference in
      let /* optionalError */ _: Error? = optionalError
      let /* databaseReference */ _: DatabaseReference = databaseReference
    }

    #if compiler(>=5.5) && canImport(_Concurrency)
      if #available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *) {
        // async/await is a Swift 5.5+ feature available on iOS 15+
        Task {
          do {
            // onDisconnectUpdateChildValues(_ values:)
            let /* ref */ _: DatabaseReference = try await DatabaseReference()
              .onDisconnectUpdateChildValues(values)
          } catch {
            // ...
          }
        }
      }
    #endif // swift(>=5.5)

    // cancelDisconnectOperations
    databaseReference.cancelDisconnectOperations()

    // cancelDisconnectOperations(completionBlock block:)
    databaseReference.cancelDisconnectOperations { optionalError, databaseReference in
      let /* optionalError */ _: Error? = optionalError
      let /* databaseReference */ _: DatabaseReference = databaseReference
    }

    #if compiler(>=5.5) && canImport(_Concurrency)
      if #available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *) {
        // async/await is a Swift 5.5+ feature available on iOS 15+
        Task {
          do {
            let /* ref */ _: DatabaseReference = try await DatabaseReference()
              .cancelDisconnectOperations()
          } catch {
            // ...
          }
        }
      }
    #endif // swift(>=5.5)

    // runTransactionBlock

    // runTransactionBlock(_ block:)
    databaseReference.runTransactionBlock { mutableData in
      let /* mutableData */ _: MutableData = mutableData
      return transactionResult
    }

    // runTransactionBlock(_ block:andCompletionBlock completionBlock:)
    databaseReference.runTransactionBlock { mutableData in
      let /* mutableData */ _: MutableData = mutableData
      return transactionResult
    } andCompletionBlock: { optionalError, bool, optionalDataSnapshot in
      let /* optionalError */ _: Error? = optionalError
      let /* bool */ _: Bool = bool
      let /* optionalDataSnapshot */ _: DataSnapshot? = optionalDataSnapshot
    }

    #if compiler(>=5.5) && canImport(_Concurrency)
      if #available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *) {
        // async/await is a Swift 5.5+ feature available on iOS 15+
        Task {
          do {
            // runTransactionBlock(_ block:)
            let _: (Bool, DataSnapshot) = try await DatabaseReference()
              .runTransactionBlock { mutableData in
                let /* mutableData */ _: MutableData = mutableData
                return TransactionResult()
              }
          } catch {
            // ...
          }
        }
      }
    #endif // swift(>=5.5)

    // runTransactionBlock(_ block:andCompletionBlock completionBlock:withLocalEvents localEvents:)
    databaseReference.runTransactionBlock({ mutableData in
      let /* mutableData */ _: MutableData = mutableData
      return transactionResult
    }, andCompletionBlock: { optionalError, bool, optionalDataSnapshot in
      let /* optionalError */ _: Error? = optionalError
      let /* bool */ _: Bool = bool
      let /* optionalDataSnapshot */ _: DataSnapshot? = optionalDataSnapshot
    }, withLocalEvents: yes)

    // description
    let /* description */ _: String = databaseReference.description()

    // Class methods
    DatabaseReference.goOffline()
    DatabaseReference.goOnline()

    // Instance properties
    let /* parent */ _: DatabaseReference? = databaseReference.parent
    let /* childKey */ _: String? = databaseReference.key
    databaseReference = databaseReference.root
    url = databaseReference.url
    database = databaseReference.database

    // MARK: - DataEventType

    let optionalDataEventType = DataEventType(rawValue: 0)

    switch optionalDataEventType {
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
    case .none, .some:
      break
    }

    // MARK: - DataSnapshot

    var dataSnapshot = DataSnapshot()

    // Navigating and inspecting a snapshot
    dataSnapshot = dataSnapshot.childSnapshot(forPath: path)
    let /* hasChild */ _: Bool = dataSnapshot.hasChild(child)
    let /* hasChildren */ _: Bool = dataSnapshot.hasChildren()
    let /* exists */ _: Bool = dataSnapshot.exists()

    // Data export
    let /* value */ _: Any? = dataSnapshot.valueInExportFormat()

    // Properties
    databaseReference = dataSnapshot.ref
    let /* value */ _: Any? = dataSnapshot.value
    let /* uint */ _: UInt = dataSnapshot.childrenCount
    let /* child */ _: String? = dataSnapshot.key
    let /* children */ _: NSEnumerator = dataSnapshot.children
    let /* priority */ _: Any? = dataSnapshot.priority

    // MARK: - MutableData

    var mutableData = MutableData()

    // Inspecting and navigating the data
    let /* hasChildren */ _: Bool = mutableData.hasChildren()
    let /* hasChild */ _: Bool = mutableData.hasChild(atPath: path)
    mutableData = mutableData.childData(byAppendingPath: path)

    // Properties
    let /* value */ _: Any? = mutableData.value
    let /* priority */ _: Any? = mutableData.priority

    let /* uint */ _: UInt = mutableData.childrenCount
    let /* children */ _: NSEnumerator = mutableData.children
    let /* childKey */ _: String? = mutableData.key

    // MARK: - ServerValue

    let nsNumber: NSNumber = 0

    let /* values */ _: [AnyHashable: Any] = ServerValue.timestamp()
    let /* values */ _: [AnyHashable: Any] = ServerValue.increment(nsNumber)

    // MARK: - TransactionResult

    transactionResult = TransactionResult.success(withValue: mutableData)
    transactionResult = TransactionResult.abort()
  }
}
