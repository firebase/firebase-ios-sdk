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

#import "FIRListenerRegistration.h"

@class FIRFirestore;
@class FIRCollectionReference;
@class FIRDocumentSnapshot;
@class FIRSetOptions;

NS_ASSUME_NONNULL_BEGIN

/**
 * Options for use with `[FIRDocumentReference addSnapshotListener]` to control the behavior of the
 * snapshot listener.
 */
NS_SWIFT_NAME(DocumentListenOptions)
@interface FIRDocumentListenOptions : NSObject

+ (instancetype)options NS_SWIFT_UNAVAILABLE("Use initializer");

- (instancetype)init;

@property(nonatomic, assign, readonly) BOOL includeMetadataChanges;

/**
 * Sets the includeMetadataChanges option which controls whether metadata-only changes (i.e. only
 * `FIRDocumentSnapshot.metadata` changed) should trigger snapshot events. Default is NO.
 *
 * @param includeMetadataChanges Whether to raise events for metadata-only changes.
 * @return The receiver is returned for optional method chaining.
 */
- (instancetype)includeMetadataChanges:(BOOL)includeMetadataChanges
    NS_SWIFT_NAME(includeMetadataChanges(_:));

@end

typedef void (^FIRDocumentSnapshotBlock)(FIRDocumentSnapshot *_Nullable snapshot,
                                         NSError *_Nullable error);

/**
 * A `FIRDocumentReference` refers to a document location in a Firestore database and can be
 * used to write, read, or listen to the location. The document at the referenced location
 * may or may not exist. A `FIRDocumentReference` can also be used to create a
 * `FIRCollectionReference` to a subcollection.
 */
NS_SWIFT_NAME(DocumentReference)
@interface FIRDocumentReference : NSObject

/**   */
- (instancetype)init
    __attribute__((unavailable("FIRDocumentReference cannot be created directly.")));

/** The ID of the document referred to. */
@property(nonatomic, strong, readonly) NSString *documentID;

/** A reference to the collection to which this `DocumentReference` belongs. */
@property(nonatomic, strong, readonly) FIRCollectionReference *parent;

/** The `FIRFirestore` for the Firestore database (useful for performing transactions, etc.). */
@property(nonatomic, strong, readonly) FIRFirestore *firestore;

/**
 * A string representing the path of the referenced document (relative to the root of the
 * database).
 */
@property(nonatomic, strong, readonly) NSString *path;

/**
 * Gets a `FIRCollectionReference` referring to the collection at the specified
 * path, relative to this document.
 *
 * @param collectionPath The slash-separated relative path of the collection for which to get a
 * `FIRCollectionReference`.
 *
 * @return The `FIRCollectionReference` at the specified _collectionPath_.
 */
- (FIRCollectionReference *)collectionWithPath:(NSString *)collectionPath
    NS_SWIFT_NAME(collection(_:));

#pragma mark - Writing Data

/**
 * Writes to the document referred to by `FIRDocumentReference`. If the document doesn't yet exist,
 * this method creates it and then sets the data. If the document exists, this method overwrites
 * the document data with the new values.
 *
 * @param documentData An `NSDictionary` that contains the fields and data to write to the
 * document.
 */
- (void)setData:(NSDictionary<NSString *, id> *)documentData;

/**
 * Writes to the document referred to by this DocumentReference. If the document does not yet
 * exist, it will be created. If you pass `FIRSetOptions`, the provided data will be merged into
 * an existing document.
 *
 * @param documentData An `NSDictionary` that contains the fields and data to write to the
 * document.
 * @param options A `FIRSetOptions` used to configure the set behavior.
 */
- (void)setData:(NSDictionary<NSString *, id> *)documentData options:(FIRSetOptions *)options;

/**
 * Overwrites the document referred to by this `FIRDocumentReference`. If no document exists, it
 * is created. If a document already exists, it is overwritten.
 *
 * @param documentData An `NSDictionary` containing the fields that make up the document
 *     to be written.
 * @param completion A block to execute once the document has been successfully written to the
 *     server. This block will not be called while the client is offline, though local
 *     changes will be visible immediately.
 */
- (void)setData:(NSDictionary<NSString *, id> *)documentData
     completion:(nullable void (^)(NSError *_Nullable error))completion;

/**
 * Writes to the document referred to by this DocumentReference. If the document does not yet
 * exist, it will be created. If you pass `FIRSetOptions`, the provided data will be merged into
 * an existing document.
 *
 * @param documentData An `NSDictionary` containing the fields that make up the document
 * to be written.
 * @param options A `FIRSetOptions` used to configure the set behavior.
 * @param completion A block to execute once the document has been successfully written to the
 *     server. This block will not be called while the client is offline, though local
 *     changes will be visible immediately.
 */
- (void)setData:(NSDictionary<NSString *, id> *)documentData
        options:(FIRSetOptions *)options
     completion:(nullable void (^)(NSError *_Nullable error))completion;

/**
 * Updates fields in the document referred to by this `FIRDocumentReference`.
 * If the document does not exist, the update fails (specify a completion block to be notified).
 *
 * @param fields An `NSDictionary` containing the fields (expressed as an `NSString` or
 *     `FIRFieldPath`) and values with which to update the document.
 */
- (void)updateData:(NSDictionary<id, id> *)fields;

/**
 * Updates fields in the document referred to by this `FIRDocumentReference`. If the document
 * does not exist, the update fails and the specified completion block receives an error.
 *
 * @param fields An `NSDictionary` containing the fields (expressed as an `NSString` or
 *     `FIRFieldPath`) and values with which to update the document.
 * @param completion A block to execute when the update is complete. If the update is successful the
 *     error parameter will be nil, otherwise it will give an indication of how the update failed.
 *     This block will only execute when the client is online and the commit has completed against
 *     the server. The completion handler will not be called when the device is offline, though
 *     local changes will be visible immediately.
 */
- (void)updateData:(NSDictionary<id, id> *)fields
        completion:(nullable void (^)(NSError *_Nullable error))completion;

// NOTE: this is named 'deleteDocument' because 'delete' is a keyword in Objective-C++.
/** Deletes the document referred to by this `FIRDocumentReference`. */
// clang-format off
- (void)deleteDocument NS_SWIFT_NAME(delete());
// clang-format on

/**
 * Deletes the document referred to by this `FIRDocumentReference`.
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
 * Reads the document referenced by this `FIRDocumentReference`.
 *
 * @param completion a block to execute once the document has been successfully read.
 */
- (void)getDocumentWithCompletion:(FIRDocumentSnapshotBlock)completion
    NS_SWIFT_NAME(getDocument(completion:));

/**
 * Attaches a listener for DocumentSnapshot events.
 *
 * @param listener The listener to attach.
 *
 * @return A FIRListenerRegistration that can be used to remove this listener.
 */
- (id<FIRListenerRegistration>)addSnapshotListener:(FIRDocumentSnapshotBlock)listener
    NS_SWIFT_NAME(addSnapshotListener(_:));

/**
 * Attaches a listener for DocumentSnapshot events.
 *
 * @param options Options controlling the listener behavior.
 * @param listener The listener to attach.
 *
 * @return A FIRListenerRegistration that can be used to remove this listener.
 */
// clang-format off
- (id<FIRListenerRegistration>)addSnapshotListenerWithOptions:
                                   (nullable FIRDocumentListenOptions *)options
                                                     listener:(FIRDocumentSnapshotBlock)listener
    NS_SWIFT_NAME(addSnapshotListener(options:listener:));
// clang-format on

@end

NS_ASSUME_NONNULL_END
