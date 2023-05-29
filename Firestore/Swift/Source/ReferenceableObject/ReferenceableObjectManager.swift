/*
 * Copyright 2023 Google LLC
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

import FirebaseFirestore

import CryptoKit
import OSLog

/// Used to fetch and save ReferenceableObjects.
///
///  To prevent refetch of the same referenced object immediately, the manager
///  also momentarily caches the referenced object. This interval is configurable.
///
///  To prevent writes of unmodified referenced objects, the manager compares checksums for the
///  object being written.
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public class ReferenceableObjectManager {
  public static var instance = ReferenceableObjectManager()

  static var settings = ReferenceableObjectManagerSettings()

  private var db = Firestore.firestore()

  private var objectCache = ReferenceableObjectCache()

  private let logPrefix = "ReferenceableObjectManager:"

  public func save<T: ReferenceableObject>(object: T) async throws {
    do {
      if let docId = object.id,
         await objectCache.contains(for: docId) {
        let encoder = Firestore.Encoder()
        let json = try encoder.encode(object)

        guard let currentDigest = computeHash(obj: json),
              await needsSave(object: object, currentDigest: currentDigest) else {
          FirestoreLogger.objectReference.debug("%@ Object doesn't need to be saved", logPrefix)
          return
        }

        try await db.collection(T.parentCollection()).document(docId).setData(json)
        await objectCache.add(object: object, digest: currentDigest)
      } else {

        let documentReference = db.collection(T.parentCollection()).document()
        try documentReference.setData(from: object)
      }

      FirestoreLogger.objectReference.debug("%@ save object complete", logPrefix)
    }
  }

  public func getObject<T: ReferenceableObject>(objectId: String) async throws -> T? {
    do {
      // first check cache
      if let cacheEntry = await objectCache.get(for: T.objectPath(objectId: objectId)) {
        return cacheEntry.object as! T
      }

      // get from db
      let documentReference = db.collection(T.parentCollection()).document(objectId)
      let doc = try await documentReference.getDocument()
      let obj = try doc.data(as: T.self)

      // cache the doc since we just fetched it from store
      if let jsonData = doc.data(),
         let digest = computeHash(obj: jsonData) {
        await objectCache.add(object: obj, digest: digest)
      }

      return obj
    }
  }

  public func getObjects<T: ReferenceableObject>(type: T.Type) async throws -> [T] {
    var foundObjects = [T]()
    do {
      let collectionRef = db.collection(type.parentCollection())
      let docSnapshot = try await collectionRef.getDocuments()

      for document in docSnapshot.documents {
        let refObj = try document.data(as: T.self)
        foundObjects.append(refObj)

        let jsonData = document.data()
        if let digest = computeHash(obj: jsonData) {
          await objectCache.add(object: refObj, digest: digest)
        }
      }
    }

    FirestoreLogger.objectReference.debug("%@ fetchObjects found %ld objects",logPrefix, foundObjects.count)

    return foundObjects
  }

  public func getObjects<T: ReferenceableObject>(predicates: [QueryPredicate]) async throws
    -> [T] {
    var query: Query = db.collection(T.parentCollection())

    query = createQuery(query: query, predicates: predicates)

    var foundObjects = [T]()
    let snapshot = try await query.getDocuments()

    for document in snapshot.documents {
      let refObj = try document.data(as: T.self)
      foundObjects.append(refObj)

      let jsonData = document.data()
      if let digest = computeHash(obj: jsonData) {
        await objectCache.add(object: refObj, digest: digest)
      }
    }

    return foundObjects
  }

  // MARK: Internal helper functions

  private func needsSave<T: ReferenceableObject>(object: T,
                                                 currentDigest: Insecure.MD5Digest) async -> Bool {
    guard let objPath = object.path else {
      // we don't have an object path so can't find cached value
      // save object
      return true
    }

    guard let cacheEntry = await objectCache.get(for: objPath) else {
      // we don't have a cached entry for this object.
      // save object
      return true
    }

    guard cacheEntry.digest == currentDigest else {
      // digests of cached object and current object to be saved don't match
      // save object
      return true
    }

    return false
  }

  private func computeHash(obj: [String: Any]) -> Insecure.MD5Digest? {
    do {
      let objData = try PropertyListSerialization.data(
        fromPropertyList: obj,
        format: .binary,
        options: .max
      )

      var md5 = Insecure.MD5()
      md5.update(data: objData)
      let digest = md5.finalize()

      return digest
    } catch {
      // this doesn't prevent functionality so not erroring here.
      FirestoreLogger.objectReference.info("Failed to compute hash")
      return nil
    }
  }

  // logic copied from FirestoreQueryObservable.swift#createListener()
  private func createQuery(query: Query, predicates: [QueryPredicate]) -> Query {
    var query = query

    for predicate in predicates {
      switch predicate {
      case let .isEqualTo(field, value):
        query = query.whereField(field, isEqualTo: value)
      case let .isIn(field, values):
        query = query.whereField(field, in: values)
      case let .isNotIn(field, values):
        query = query.whereField(field, notIn: values)
      case let .arrayContains(field, value):
        query = query.whereField(field, arrayContains: value)
      case let .arrayContainsAny(field, values):
        query = query.whereField(field, arrayContainsAny: values)
      case let .isLessThan(field, value):
        query = query.whereField(field, isLessThan: value)
      case let .isGreaterThan(field, value):
        query = query.whereField(field, isGreaterThan: value)
      case let .isLessThanOrEqualTo(field, value):
        query = query.whereField(field, isLessThanOrEqualTo: value)
      case let .isGreaterThanOrEqualTo(field, value):
        query = query.whereField(field, isGreaterThanOrEqualTo: value)
      case let .orderBy(field, value):
        query = query.order(by: field, descending: value)
      case let .limitTo(field):
        query = query.limit(to: field)
      case let .limitToLast(field):
        query = query.limit(toLast: field)
      }
    }

    return query
  }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
struct ReferenceableObjectManagerSettings {
  // how long to cache object
  // the purpose is not to cache for a long time
  var cacheValidityInterval: TimeInterval = 5.0 // seconds
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
private struct ReferenceableObjectCacheEntry {
  var digest: Insecure.MD5Digest
  var object: any ReferenceableObject
  var insertTime: TimeInterval
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
private actor ReferenceableObjectCache {
  var cache = [String: ReferenceableObjectCacheEntry]()

  func add<T: ReferenceableObject>(object: T, digest: Insecure.MD5Digest) {
    if let docId = object.id {
      cache[docId] = ReferenceableObjectCacheEntry(
        digest: digest,
        object: object,
        insertTime: Date().timeIntervalSince1970
      )
      FirestoreLogger.objectReference.debug("Added object to cache %@", docId)
    }
  }

  func get(for docId: String) -> ReferenceableObjectCacheEntry? {
    guard let entry = cache[docId] else {
      return nil
    }

    let now = Date().timeIntervalSince1970
    let cacheTime = ReferenceableObjectManager.settings.cacheValidityInterval
    guard now - entry.insertTime < cacheTime else {
      // older entry - invalidate it
      cache[docId] = nil
      return nil
    }

    return cache[docId]
  }

  func contains(for docId: String) -> Bool {
    guard cache[docId] != nil else {
      return false
    }

    return true
  }

  func removeAll() {
    cache.removeAll()
  }
}
