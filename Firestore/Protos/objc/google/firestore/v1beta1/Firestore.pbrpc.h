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

#if !GPB_GRPC_FORWARD_DECLARE_MESSAGE_PROTO
#import "Firestore.pbobjc.h"
#endif

#import <ProtoRPC/ProtoService.h>
#import <ProtoRPC/ProtoRPC.h>
#import <RxLibrary/GRXWriteable.h>
#import <RxLibrary/GRXWriter.h>

#if GPB_GRPC_FORWARD_DECLARE_MESSAGE_PROTO
  @class GCFSBatchGetDocumentsRequest;
  @class GCFSBatchGetDocumentsResponse;
  @class GCFSBeginTransactionRequest;
  @class GCFSBeginTransactionResponse;
  @class GCFSCommitRequest;
  @class GCFSCommitResponse;
  @class GCFSCreateDocumentRequest;
  @class GCFSDeleteDocumentRequest;
  @class GCFSDocument;
  @class GCFSGetDocumentRequest;
  @class GCFSListCollectionIdsRequest;
  @class GCFSListCollectionIdsResponse;
  @class GCFSListDocumentsRequest;
  @class GCFSListDocumentsResponse;
  @class GCFSListenRequest;
  @class GCFSListenResponse;
  @class GCFSRollbackRequest;
  @class GCFSRunQueryRequest;
  @class GCFSRunQueryResponse;
  @class GCFSUpdateDocumentRequest;
  @class GCFSWriteRequest;
  @class GCFSWriteResponse;
  @class GPBEmpty;
#else
  #import "Annotations.pbobjc.h"
  #import "Common.pbobjc.h"
  #import "Document.pbobjc.h"
  #import "Query.pbobjc.h"
  #import "Write.pbobjc.h"
  #if GPB_USE_PROTOBUF_FRAMEWORK_IMPORTS
    #import <Protobuf/Empty.pbobjc.h>
  #else
    #import "Empty.pbobjc.h"
  #endif
  #if GPB_USE_PROTOBUF_FRAMEWORK_IMPORTS
    #import <Protobuf/Timestamp.pbobjc.h>
  #else
    #import "Timestamp.pbobjc.h"
  #endif
  #import "Status.pbobjc.h"
#endif


NS_ASSUME_NONNULL_BEGIN

@protocol GCFSFirestore <NSObject>

#pragma mark GetDocument(GetDocumentRequest) returns (Document)

/**
 * Gets a single document.
 */
- (void)getDocumentWithRequest:(GCFSGetDocumentRequest *)request handler:(void(^)(GCFSDocument *_Nullable response, NSError *_Nullable error))handler;

/**
 * Gets a single document.
 */
- (GRPCProtoCall *)RPCToGetDocumentWithRequest:(GCFSGetDocumentRequest *)request handler:(void(^)(GCFSDocument *_Nullable response, NSError *_Nullable error))handler;


#pragma mark ListDocuments(ListDocumentsRequest) returns (ListDocumentsResponse)

/**
 * Lists documents.
 */
- (void)listDocumentsWithRequest:(GCFSListDocumentsRequest *)request handler:(void(^)(GCFSListDocumentsResponse *_Nullable response, NSError *_Nullable error))handler;

/**
 * Lists documents.
 */
- (GRPCProtoCall *)RPCToListDocumentsWithRequest:(GCFSListDocumentsRequest *)request handler:(void(^)(GCFSListDocumentsResponse *_Nullable response, NSError *_Nullable error))handler;


#pragma mark CreateDocument(CreateDocumentRequest) returns (Document)

/**
 * Creates a new document.
 */
- (void)createDocumentWithRequest:(GCFSCreateDocumentRequest *)request handler:(void(^)(GCFSDocument *_Nullable response, NSError *_Nullable error))handler;

/**
 * Creates a new document.
 */
- (GRPCProtoCall *)RPCToCreateDocumentWithRequest:(GCFSCreateDocumentRequest *)request handler:(void(^)(GCFSDocument *_Nullable response, NSError *_Nullable error))handler;


#pragma mark UpdateDocument(UpdateDocumentRequest) returns (Document)

/**
 * Updates or inserts a document.
 */
- (void)updateDocumentWithRequest:(GCFSUpdateDocumentRequest *)request handler:(void(^)(GCFSDocument *_Nullable response, NSError *_Nullable error))handler;

/**
 * Updates or inserts a document.
 */
- (GRPCProtoCall *)RPCToUpdateDocumentWithRequest:(GCFSUpdateDocumentRequest *)request handler:(void(^)(GCFSDocument *_Nullable response, NSError *_Nullable error))handler;


#pragma mark DeleteDocument(DeleteDocumentRequest) returns (Empty)

/**
 * Deletes a document.
 */
- (void)deleteDocumentWithRequest:(GCFSDeleteDocumentRequest *)request handler:(void(^)(GPBEmpty *_Nullable response, NSError *_Nullable error))handler;

/**
 * Deletes a document.
 */
- (GRPCProtoCall *)RPCToDeleteDocumentWithRequest:(GCFSDeleteDocumentRequest *)request handler:(void(^)(GPBEmpty *_Nullable response, NSError *_Nullable error))handler;


#pragma mark BatchGetDocuments(BatchGetDocumentsRequest) returns (stream BatchGetDocumentsResponse)

/**
 * Gets multiple documents.
 *
 * Documents returned by this method are not guaranteed to be returned in the
 * same order that they were requested.
 */
- (void)batchGetDocumentsWithRequest:(GCFSBatchGetDocumentsRequest *)request eventHandler:(void(^)(BOOL done, GCFSBatchGetDocumentsResponse *_Nullable response, NSError *_Nullable error))eventHandler;

/**
 * Gets multiple documents.
 *
 * Documents returned by this method are not guaranteed to be returned in the
 * same order that they were requested.
 */
- (GRPCProtoCall *)RPCToBatchGetDocumentsWithRequest:(GCFSBatchGetDocumentsRequest *)request eventHandler:(void(^)(BOOL done, GCFSBatchGetDocumentsResponse *_Nullable response, NSError *_Nullable error))eventHandler;


#pragma mark BeginTransaction(BeginTransactionRequest) returns (BeginTransactionResponse)

/**
 * Starts a new transaction.
 */
- (void)beginTransactionWithRequest:(GCFSBeginTransactionRequest *)request handler:(void(^)(GCFSBeginTransactionResponse *_Nullable response, NSError *_Nullable error))handler;

/**
 * Starts a new transaction.
 */
- (GRPCProtoCall *)RPCToBeginTransactionWithRequest:(GCFSBeginTransactionRequest *)request handler:(void(^)(GCFSBeginTransactionResponse *_Nullable response, NSError *_Nullable error))handler;


#pragma mark Commit(CommitRequest) returns (CommitResponse)

/**
 * Commits a transaction, while optionally updating documents.
 */
- (void)commitWithRequest:(GCFSCommitRequest *)request handler:(void(^)(GCFSCommitResponse *_Nullable response, NSError *_Nullable error))handler;

/**
 * Commits a transaction, while optionally updating documents.
 */
- (GRPCProtoCall *)RPCToCommitWithRequest:(GCFSCommitRequest *)request handler:(void(^)(GCFSCommitResponse *_Nullable response, NSError *_Nullable error))handler;


#pragma mark Rollback(RollbackRequest) returns (Empty)

/**
 * Rolls back a transaction.
 */
- (void)rollbackWithRequest:(GCFSRollbackRequest *)request handler:(void(^)(GPBEmpty *_Nullable response, NSError *_Nullable error))handler;

/**
 * Rolls back a transaction.
 */
- (GRPCProtoCall *)RPCToRollbackWithRequest:(GCFSRollbackRequest *)request handler:(void(^)(GPBEmpty *_Nullable response, NSError *_Nullable error))handler;


#pragma mark RunQuery(RunQueryRequest) returns (stream RunQueryResponse)

/**
 * Runs a query.
 */
- (void)runQueryWithRequest:(GCFSRunQueryRequest *)request eventHandler:(void(^)(BOOL done, GCFSRunQueryResponse *_Nullable response, NSError *_Nullable error))eventHandler;

/**
 * Runs a query.
 */
- (GRPCProtoCall *)RPCToRunQueryWithRequest:(GCFSRunQueryRequest *)request eventHandler:(void(^)(BOOL done, GCFSRunQueryResponse *_Nullable response, NSError *_Nullable error))eventHandler;


#pragma mark Write(stream WriteRequest) returns (stream WriteResponse)

/**
 * Streams batches of document updates and deletes, in order.
 */
- (void)writeWithRequestsWriter:(GRXWriter *)requestWriter eventHandler:(void(^)(BOOL done, GCFSWriteResponse *_Nullable response, NSError *_Nullable error))eventHandler;

/**
 * Streams batches of document updates and deletes, in order.
 */
- (GRPCProtoCall *)RPCToWriteWithRequestsWriter:(GRXWriter *)requestWriter eventHandler:(void(^)(BOOL done, GCFSWriteResponse *_Nullable response, NSError *_Nullable error))eventHandler;


#pragma mark Listen(stream ListenRequest) returns (stream ListenResponse)

/**
 * Listens to changes.
 */
- (void)listenWithRequestsWriter:(GRXWriter *)requestWriter eventHandler:(void(^)(BOOL done, GCFSListenResponse *_Nullable response, NSError *_Nullable error))eventHandler;

/**
 * Listens to changes.
 */
- (GRPCProtoCall *)RPCToListenWithRequestsWriter:(GRXWriter *)requestWriter eventHandler:(void(^)(BOOL done, GCFSListenResponse *_Nullable response, NSError *_Nullable error))eventHandler;


#pragma mark ListCollectionIds(ListCollectionIdsRequest) returns (ListCollectionIdsResponse)

/**
 * Lists all the collection IDs underneath a document.
 */
- (void)listCollectionIdsWithRequest:(GCFSListCollectionIdsRequest *)request handler:(void(^)(GCFSListCollectionIdsResponse *_Nullable response, NSError *_Nullable error))handler;

/**
 * Lists all the collection IDs underneath a document.
 */
- (GRPCProtoCall *)RPCToListCollectionIdsWithRequest:(GCFSListCollectionIdsRequest *)request handler:(void(^)(GCFSListCollectionIdsResponse *_Nullable response, NSError *_Nullable error))handler;


@end

/**
 * Basic service implementation, over gRPC, that only does
 * marshalling and parsing.
 */
@interface GCFSFirestore : GRPCProtoService<GCFSFirestore>
- (instancetype)initWithHost:(NSString *)host NS_DESIGNATED_INITIALIZER;
+ (instancetype)serviceWithHost:(NSString *)host;
@end

NS_ASSUME_NONNULL_END
