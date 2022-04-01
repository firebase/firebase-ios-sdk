/*
 * Copyright 2017 Google
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

#import <Foundation/Foundation.h>

#import "FIRFirestoreSource.h"
#import "FIRListenerRegistration.h"

@class FIRCollectionReference;
@class FIRDocumentSnapshot;
@class FIRFirestore;

NS_ASSUME_NONNULL_BEGIN

/**
 * A block type used to handle snapshot updates.
 */
typedef void (^FIRDocumentSnapshotBlock)(FIRDocumentSnapshot *_Nullable snapshot,
                                         NSError *_Nullable error);

/**
 * A `DocumentReference` refers to a document location in a Firestore database and can be
 * used to write, read, or listen to the location. The document at the referenced location
 * may or may not exist. A `DocumentReference` can also be used to create a `CollectionReference` to
 * a subcollection.
 */
NS_SWIFT_NAME(DocumentReference)
@interface FIRDocumentReference : NSObject

/** :nodoc: */
- (instancetype)init
    __attribute__((unavailable("FIRDocumentReference cannot be created directly.")));

/** The ID of the document referred to. */
@property(nonatomic, strong, readonly) NSString *documentID;

/** A reference to the collection to which this `DocumentReference` belongs. */
@property(nonatomic, strong, readonly) FIRCollectionReference *parent;

/** The `Firestore` for the Firestore database (useful for performing transactions, etc.). */
@property(nonatomic, strong, readonly) FIRFirestore *firestore;

/**
 * A string representing the path of the referenced document (relative to the root of the
 * database).
 */
@property(nonatomic, strong, readonly) NSString *path;

/**
 * Gets a `CollectionReference` referring to the collection at the specified path, relative to this
 * document.
 *
 * @param collectionPath The slash-separated relative path of the collection for which to get a
 * `CollectionReference`.
 *
 * @return The `CollectionReference` at the specified _collectionPath_.
 */
- (FIRCollectionReference *)collectionWithPath:(NSString *)collectionPath
    NS_SWIFT_NAME(collection(_:));

#pragma mark - Writing Data

/**
 * Writes to the document referred to by `DocumentReference`. If the document doesn't yet exist,
 * this method creates it and then sets the data. If the document exists, this method overwrites
 * the document data with the new values.
 *
 * @param documentData A `Dictionary` that contains the fields and data to write to the
 * document.
 */
- (void)setData:(NSDictionary<NSString *, id> *)documentData;

/**
 * Writes to the document referred to by this `DocumentReference`. If the document does not yet
 * exist, it will be created. If you pass `merge:true`, the provided data will be merged into
 * any existing document.
 *
 * @param documentData A `Dictionary` that contains the fields and data to write to the
 * document.
 * @param merge Whether to merge the provided data into any existing document. If enabled,
 * all omitted fields remain untouched. If your input sets any field to an empty dictionary, any
 * nested field is overwritten.
 */
- (void)setData:(NSDictionary<NSString *, id> *)documentData merge:(BOOL)merge;

/**
 * Writes to the document referred to by `document` and only replace the fields
 * specified under `mergeFields`. Any field that is not specified in `mergeFields`
 * is ignored and remains untouched. If the document doesn't yet exist,
 * this method creates it and then sets the data.
 *
 * It is an error to include a field in `mergeFields` that does not have a corresponding
 * value in the `data` dictionary.
 *
 * @param documentData A `Dictionary` containing the fields that make up the document
 * to be written.
 * @param mergeFields An `Array` that contains a list of `String` or `FieldPath` elements
 * specifying which fields to merge. Fields can contain dots to reference nested fields within
 * the document. If your input sets any field to an empty dictionary, any nested field is
 * overwritten.
 */
- (void)setData:(NSDictionary<NSString *, id> *)documentData mergeFields:(NSArray<id> *)mergeFields;

/**
 * Overwrites the document referred to by this `DocumentReference`. If no document exists, it
 * is created. If a document already exists, it is overwritten.
 *
 * @param documentData A `Dictionary` containing the fields that make up the document
 *     to be written.
 * @param completion A block to execute once the document has been successfully written to the
 *     server. This block will not be called while the client is offline, though local
 *     changes will be visible immediately.
 */
- (void)setData:(NSDictionary<NSString *, id> *)documentData
     completion:(nullable void (^)(NSError *_Nullable error))completion;

/**
 * Writes to the document referred to by this `DocumentReference`. If the document does not yet
 * exist, it will be created. If you pass `merge:true`, the provided data will be merged into
 * any existing document.
 *
 * @param documentData A `Dictionary` containing the fields that make up the document
 * to be written.
 * @param merge Whether to merge the provided data into any existing document. If your input sets
 *     any field to an empty dictionary, any nested field is overwritten.
 * @param completion A block to execute once the document has been successfully written to the
 *     server. This block will not be called while the client is offline, though local
 *     changes will be visible immediately.
 */
- (void)setData:(NSDictionary<NSString *, id> *)documentData
          merge:(BOOL)merge
     completion:(nullable void (^)(NSError *_Nullable error))completion;

/**
 * Writes to the document referred to by `document` and only replace the fields
 * specified under `mergeFields`. Any field that is not specified in `mergeFields`
 * is ignored and remains untouched. If the document doesn't yet exist,
 * this method creates it and then sets the data.
 *
 * It is an error to include a field in `mergeFields` that does not have a corresponding
 * value in the `data` dictionary.
 *
 * @param documentData A `Dictionary` containing the fields that make up the document
 * to be written.
 * @param mergeFields An `Array` that contains a list of `String` or `FieldPath` elements
 *     specifying which fields to merge. Fields can contain dots to reference nested fields within
 *     the document. If your input sets any field to an empty dictionary, any nested field is
 *     overwritten.
 * @param completion A block to execute once the document has been successfully written to the
 *     server. This block will not be called while the client is offline, though local
 *     changes will be visible immediately.
 */
- (void)setData:(NSDictionary<NSString *, id> *)documentData
    mergeFields:(NSArray<id> *)mergeFields
     completion:(nullable void (^)(NSError *_Nullable error))completion;

/**
 * Updates fields in the document referred to by this `DocumentReference`.
 * If the document does not exist, the update fails (specify a completion block to be notified).
 *
 * @param fields A `Dictionary` containing the fields (expressed as an `String` or
 *     `FieldPath`) and values with which to update the document.
 */
- (void)updateData:(NSDictionary<id, id> *)fields;

/**
 * Updates fields in the document referred to by this `DocumentReference`. If the document
 * does not exist, the update fails and the specified completion block receives an error.
 *
 * @param fields A `Dictionary` containing the fields (expressed as a `String` or
 *     `FieldPath`) and values with which to update the document.
 * @param completion A block to execute when the update is complete. If the update is successful the
 *     error parameter will be nil, otherwise it will give an indication of how the update failed.
 *     This block will only execute when the client is online and the commit has completed against
 *     the server. The completion handler will not be called when the device is offline, though
 *     local changes will be visible immediately.
 */
- (void)updateData:(NSDictionary<id, id> *)fields
        completion:(nullable void (^)(NSError *_Nullable error))completion;

// NOTE: this method is named 'deleteDocument' in Objective-C because 'delete' is a keyword in
// Objective-C++.
/** Deletes the document referred to by this `DocumentReference`. */
// clang-format off
- (void)deleteDocument NS_SWIFT_NAME(delete());
// clang-format on

/**
 * Deletes the document referred to by this `DocumentReference`.
 *
 * @param completion A block to execute once the document has been successfully written to the
 *     server. This block will not be called while the client is offline, though local
 *     changes will be visible immediately.
 */
// clang-format off
- (void)deleteDocumentWithCompletion:(nullable void (^)(NSError *_Nullable error))completion
    NS_SWIFT_NAME(delete(completion:));
// clang-format on

#pragma mark - Retrieving Data

/**
 * Reads the document referenced by this `DocumentReference`.
 *
 * This method attempts to provide up-to-date data when possible by waiting for
 * data from the server, but it may return cached data or fail if you are
 * offline and the server cannot be reached. See the
 * `getDocument(source:completion:)` method to change this behavior.
 *
 * @param completion a block to execute once the document has been successfully read.
 */
- (void)getDocumentWithCompletion:(FIRDocumentSnapshotBlock)completion
    NS_SWIFT_NAME(getDocument(completion:));

/**
 * Reads the document referenced by this `DocumentReference`.
 *
 * @param source indicates whether the results should be fetched from the cache
 *     only (`Source.cache`), the server only (`Source.server`), or to attempt
 *     the server and fall back to the cache (`Source.default`).
 * @param completion a block to execute once the document has been successfully read.
 */
// clang-format off
- (void)getDocumentWithSource:(FIRFirestoreSource)source
                   completion:(FIRDocumentSnapshotBlock)completion
    NS_SWIFT_NAME(getDocument(source:completion:));
// clang-format on

/**
 * Attaches a listener for `DocumentSnapshot` events.
 *
 * @param listener The listener to attach.
 *
 * @return A `ListenerRegistration` that can be used to remove this listener.
 */
- (id<FIRListenerRegistration>)addSnapshotListener:(FIRDocumentSnapshotBlock)listener
    NS_SWIFT_NAME(addSnapshotListener(_:));

/**
 * Attaches a listener for `DocumentSnapshot` events.
 *
 * @param includeMetadataChanges Whether metadata-only changes (i.e. only
 *     `DocumentSnapshot.metadata` changed) should trigger snapshot events.
 * @param listener The listener to attach.
 *
 * @return A `ListenerRegistration` that can be used to remove this listener.
 */
// clang-format off
- (id<FIRListenerRegistration>)
addSnapshotListenerWithIncludeMetadataChanges:(BOOL)includeMetadataChanges
                                     listener:(FIRDocumentSnapshotBlock)listener
    NS_SWIFT_NAME(addSnapshotListener(includeMetadataChanges:listener:));
// clang-format on

@end

NS_ASSUME_NONNULL_END
