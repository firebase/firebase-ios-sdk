/*
 * Copyright 2018 Google
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

#import "Firestore.pbrpc.h"
#import "Firestore.pbobjc.h"

#import <ProtoRPC/ProtoRPC.h>
#import <RxLibrary/GRXWriter+Immediate.h>
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

@implementation GCFSFirestore

// Designated initializer
- (instancetype)initWithHost:(NSString *)host {
  return (self = [super initWithHost:host packageName:@"google.firestore.v1beta1" serviceName:@"Firestore"]);
}

// Override superclass initializer to disallow different package and service names.
- (instancetype)initWithHost:(NSString *)host
                 packageName:(NSString *)packageName
                 serviceName:(NSString *)serviceName {
  return [self initWithHost:host];
}

+ (instancetype)serviceWithHost:(NSString *)host {
  return [[self alloc] initWithHost:host];
}


#pragma mark GetDocument(GetDocumentRequest) returns (Document)

/**
 * Gets a single document.
 */
- (void)getDocumentWithRequest:(GCFSGetDocumentRequest *)request handler:(void(^)(GCFSDocument *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToGetDocumentWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Gets a single document.
 */
- (GRPCProtoCall *)RPCToGetDocumentWithRequest:(GCFSGetDocumentRequest *)request handler:(void(^)(GCFSDocument *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"GetDocument"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[GCFSDocument class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark ListDocuments(ListDocumentsRequest) returns (ListDocumentsResponse)

/**
 * Lists documents.
 */
- (void)listDocumentsWithRequest:(GCFSListDocumentsRequest *)request handler:(void(^)(GCFSListDocumentsResponse *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToListDocumentsWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Lists documents.
 */
- (GRPCProtoCall *)RPCToListDocumentsWithRequest:(GCFSListDocumentsRequest *)request handler:(void(^)(GCFSListDocumentsResponse *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"ListDocuments"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[GCFSListDocumentsResponse class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark CreateDocument(CreateDocumentRequest) returns (Document)

/**
 * Creates a new document.
 */
- (void)createDocumentWithRequest:(GCFSCreateDocumentRequest *)request handler:(void(^)(GCFSDocument *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToCreateDocumentWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Creates a new document.
 */
- (GRPCProtoCall *)RPCToCreateDocumentWithRequest:(GCFSCreateDocumentRequest *)request handler:(void(^)(GCFSDocument *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"CreateDocument"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[GCFSDocument class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark UpdateDocument(UpdateDocumentRequest) returns (Document)

/**
 * Updates or inserts a document.
 */
- (void)updateDocumentWithRequest:(GCFSUpdateDocumentRequest *)request handler:(void(^)(GCFSDocument *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToUpdateDocumentWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Updates or inserts a document.
 */
- (GRPCProtoCall *)RPCToUpdateDocumentWithRequest:(GCFSUpdateDocumentRequest *)request handler:(void(^)(GCFSDocument *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"UpdateDocument"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[GCFSDocument class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark DeleteDocument(DeleteDocumentRequest) returns (Empty)

/**
 * Deletes a document.
 */
- (void)deleteDocumentWithRequest:(GCFSDeleteDocumentRequest *)request handler:(void(^)(GPBEmpty *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToDeleteDocumentWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Deletes a document.
 */
- (GRPCProtoCall *)RPCToDeleteDocumentWithRequest:(GCFSDeleteDocumentRequest *)request handler:(void(^)(GPBEmpty *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"DeleteDocument"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[GPBEmpty class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark BatchGetDocuments(BatchGetDocumentsRequest) returns (stream BatchGetDocumentsResponse)

/**
 * Gets multiple documents.
 *
 * Documents returned by this method are not guaranteed to be returned in the
 * same order that they were requested.
 */
- (void)batchGetDocumentsWithRequest:(GCFSBatchGetDocumentsRequest *)request eventHandler:(void(^)(BOOL done, GCFSBatchGetDocumentsResponse *_Nullable response, NSError *_Nullable error))eventHandler{
  [[self RPCToBatchGetDocumentsWithRequest:request eventHandler:eventHandler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Gets multiple documents.
 *
 * Documents returned by this method are not guaranteed to be returned in the
 * same order that they were requested.
 */
- (GRPCProtoCall *)RPCToBatchGetDocumentsWithRequest:(GCFSBatchGetDocumentsRequest *)request eventHandler:(void(^)(BOOL done, GCFSBatchGetDocumentsResponse *_Nullable response, NSError *_Nullable error))eventHandler{
  return [self RPCToMethod:@"BatchGetDocuments"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[GCFSBatchGetDocumentsResponse class]
        responsesWriteable:[GRXWriteable writeableWithEventHandler:eventHandler]];
}
#pragma mark BeginTransaction(BeginTransactionRequest) returns (BeginTransactionResponse)

/**
 * Starts a new transaction.
 */
- (void)beginTransactionWithRequest:(GCFSBeginTransactionRequest *)request handler:(void(^)(GCFSBeginTransactionResponse *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToBeginTransactionWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Starts a new transaction.
 */
- (GRPCProtoCall *)RPCToBeginTransactionWithRequest:(GCFSBeginTransactionRequest *)request handler:(void(^)(GCFSBeginTransactionResponse *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"BeginTransaction"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[GCFSBeginTransactionResponse class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark Commit(CommitRequest) returns (CommitResponse)

/**
 * Commits a transaction, while optionally updating documents.
 */
- (void)commitWithRequest:(GCFSCommitRequest *)request handler:(void(^)(GCFSCommitResponse *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToCommitWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Commits a transaction, while optionally updating documents.
 */
- (GRPCProtoCall *)RPCToCommitWithRequest:(GCFSCommitRequest *)request handler:(void(^)(GCFSCommitResponse *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"Commit"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[GCFSCommitResponse class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark Rollback(RollbackRequest) returns (Empty)

/**
 * Rolls back a transaction.
 */
- (void)rollbackWithRequest:(GCFSRollbackRequest *)request handler:(void(^)(GPBEmpty *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToRollbackWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Rolls back a transaction.
 */
- (GRPCProtoCall *)RPCToRollbackWithRequest:(GCFSRollbackRequest *)request handler:(void(^)(GPBEmpty *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"Rollback"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[GPBEmpty class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark RunQuery(RunQueryRequest) returns (stream RunQueryResponse)

/**
 * Runs a query.
 */
- (void)runQueryWithRequest:(GCFSRunQueryRequest *)request eventHandler:(void(^)(BOOL done, GCFSRunQueryResponse *_Nullable response, NSError *_Nullable error))eventHandler{
  [[self RPCToRunQueryWithRequest:request eventHandler:eventHandler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Runs a query.
 */
- (GRPCProtoCall *)RPCToRunQueryWithRequest:(GCFSRunQueryRequest *)request eventHandler:(void(^)(BOOL done, GCFSRunQueryResponse *_Nullable response, NSError *_Nullable error))eventHandler{
  return [self RPCToMethod:@"RunQuery"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[GCFSRunQueryResponse class]
        responsesWriteable:[GRXWriteable writeableWithEventHandler:eventHandler]];
}
#pragma mark Write(stream WriteRequest) returns (stream WriteResponse)

/**
 * Streams batches of document updates and deletes, in order.
 */
- (void)writeWithRequestsWriter:(GRXWriter *)requestWriter eventHandler:(void(^)(BOOL done, GCFSWriteResponse *_Nullable response, NSError *_Nullable error))eventHandler{
  [[self RPCToWriteWithRequestsWriter:requestWriter eventHandler:eventHandler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Streams batches of document updates and deletes, in order.
 */
- (GRPCProtoCall *)RPCToWriteWithRequestsWriter:(GRXWriter *)requestWriter eventHandler:(void(^)(BOOL done, GCFSWriteResponse *_Nullable response, NSError *_Nullable error))eventHandler{
  return [self RPCToMethod:@"Write"
            requestsWriter:requestWriter
             responseClass:[GCFSWriteResponse class]
        responsesWriteable:[GRXWriteable writeableWithEventHandler:eventHandler]];
}
#pragma mark Listen(stream ListenRequest) returns (stream ListenResponse)

/**
 * Listens to changes.
 */
- (void)listenWithRequestsWriter:(GRXWriter *)requestWriter eventHandler:(void(^)(BOOL done, GCFSListenResponse *_Nullable response, NSError *_Nullable error))eventHandler{
  [[self RPCToListenWithRequestsWriter:requestWriter eventHandler:eventHandler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Listens to changes.
 */
- (GRPCProtoCall *)RPCToListenWithRequestsWriter:(GRXWriter *)requestWriter eventHandler:(void(^)(BOOL done, GCFSListenResponse *_Nullable response, NSError *_Nullable error))eventHandler{
  return [self RPCToMethod:@"Listen"
            requestsWriter:requestWriter
             responseClass:[GCFSListenResponse class]
        responsesWriteable:[GRXWriteable writeableWithEventHandler:eventHandler]];
}
#pragma mark ListCollectionIds(ListCollectionIdsRequest) returns (ListCollectionIdsResponse)

/**
 * Lists all the collection IDs underneath a document.
 */
- (void)listCollectionIdsWithRequest:(GCFSListCollectionIdsRequest *)request handler:(void(^)(GCFSListCollectionIdsResponse *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToListCollectionIdsWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Lists all the collection IDs underneath a document.
 */
- (GRPCProtoCall *)RPCToListCollectionIdsWithRequest:(GCFSListCollectionIdsRequest *)request handler:(void(^)(GCFSListCollectionIdsResponse *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"ListCollectionIds"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[GCFSListCollectionIdsResponse class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
@end
