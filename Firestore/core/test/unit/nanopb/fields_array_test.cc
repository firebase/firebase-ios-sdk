/*
 * Copyright 2022 Google LLC
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

#include "Firestore/core/src/nanopb/fields_array.h"

#include "gmock/gmock.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace nanopb {
namespace {

TEST(FieldsArrayTest, firestore_client_MaybeDocument) {
  ASSERT_EQ(FieldsArray<firestore_client_MaybeDocument>(),
            firestore_client_MaybeDocument_fields);
}

TEST(FieldsArrayTest, firestore_client_MutationQueue) {
  ASSERT_EQ(FieldsArray<firestore_client_MutationQueue>(),
            firestore_client_MutationQueue_fields);
}

TEST(FieldsArrayTest, firestore_client_Target) {
  ASSERT_EQ(FieldsArray<firestore_client_Target>(),
            firestore_client_Target_fields);
}

TEST(FieldsArrayTest, firestore_client_TargetGlobal) {
  ASSERT_EQ(FieldsArray<firestore_client_TargetGlobal>(),
            firestore_client_TargetGlobal_fields);
}

TEST(FieldsArrayTest, firestore_client_WriteBatch) {
  ASSERT_EQ(FieldsArray<firestore_client_WriteBatch>(),
            firestore_client_WriteBatch_fields);
}

TEST(FieldsArrayTest, google_firestore_v1_BatchGetDocumentsRequest) {
  ASSERT_EQ(FieldsArray<google_firestore_v1_BatchGetDocumentsRequest>(),
            google_firestore_v1_BatchGetDocumentsRequest_fields);
}

TEST(FieldsArrayTest, google_firestore_v1_BatchGetDocumentsResponse) {
  ASSERT_EQ(FieldsArray<google_firestore_v1_BatchGetDocumentsResponse>(),
            google_firestore_v1_BatchGetDocumentsResponse_fields);
}

TEST(FieldsArrayTest, google_firestore_v1_CommitRequest) {
  ASSERT_EQ(FieldsArray<google_firestore_v1_CommitRequest>(),
            google_firestore_v1_CommitRequest_fields);
}

TEST(FieldsArrayTest, google_firestore_v1_CommitResponse) {
  ASSERT_EQ(FieldsArray<google_firestore_v1_CommitResponse>(),
            google_firestore_v1_CommitResponse_fields);
}

TEST(FieldsArrayTest, google_firestore_v1_ListenRequest) {
  ASSERT_EQ(FieldsArray<google_firestore_v1_ListenRequest>(),
            google_firestore_v1_ListenRequest_fields);
}

TEST(FieldsArrayTest, google_firestore_v1_ListenResponse) {
  ASSERT_EQ(FieldsArray<google_firestore_v1_ListenResponse>(),
            google_firestore_v1_ListenResponse_fields);
}

TEST(FieldsArrayTest, google_firestore_v1_RunQueryRequest) {
  ASSERT_EQ(FieldsArray<google_firestore_v1_RunQueryRequest>(),
            google_firestore_v1_RunQueryRequest_fields);
}

TEST(FieldsArrayTest, google_firestore_v1_StructuredQuery_Filter) {
  ASSERT_EQ(FieldsArray<google_firestore_v1_StructuredQuery_Filter>(),
            google_firestore_v1_StructuredQuery_Filter_fields);
}

TEST(FieldsArrayTest, google_firestore_v1_Target_DocumentsTarget) {
  ASSERT_EQ(FieldsArray<google_firestore_v1_Target_DocumentsTarget>(),
            google_firestore_v1_Target_DocumentsTarget_fields);
}

TEST(FieldsArrayTest, google_firestore_v1_TargetChange) {
  ASSERT_EQ(FieldsArray<google_firestore_v1_TargetChange>(),
            google_firestore_v1_TargetChange_fields);
}

TEST(FieldsArrayTest, google_firestore_v1_Target_QueryTarget) {
  ASSERT_EQ(FieldsArray<google_firestore_v1_Target_QueryTarget>(),
            google_firestore_v1_Target_QueryTarget_fields);
}

TEST(FieldsArrayTest, google_firestore_v1_Value) {
  ASSERT_EQ(FieldsArray<google_firestore_v1_Value>(),
            google_firestore_v1_Value_fields);
}

TEST(FieldsArrayTest, google_firestore_v1_ArrayValue) {
  ASSERT_EQ(FieldsArray<google_firestore_v1_ArrayValue>(),
            google_firestore_v1_ArrayValue_fields);
}

TEST(FieldsArrayTest, google_firestore_v1_MapValue) {
  ASSERT_EQ(FieldsArray<google_firestore_v1_MapValue>(),
            google_firestore_v1_MapValue_fields);
}

TEST(FieldsArrayTest, google_firestore_v1_MapValue_FieldsEntry) {
  ASSERT_EQ(FieldsArray<google_firestore_v1_MapValue_FieldsEntry>(),
            google_firestore_v1_MapValue_FieldsEntry_fields);
}

TEST(FieldsArrayTest, google_firestore_v1_Write) {
  ASSERT_EQ(FieldsArray<google_firestore_v1_Write>(),
            google_firestore_v1_Write_fields);
}

TEST(FieldsArrayTest, google_firestore_v1_WriteRequest) {
  ASSERT_EQ(FieldsArray<google_firestore_v1_WriteRequest>(),
            google_firestore_v1_WriteRequest_fields);
}

TEST(FieldsArrayTest, google_firestore_v1_WriteResponse) {
  ASSERT_EQ(FieldsArray<google_firestore_v1_WriteResponse>(),
            google_firestore_v1_WriteResponse_fields);
}

TEST(FieldsArrayTest, google_firestore_v1_WriteResult) {
  ASSERT_EQ(FieldsArray<google_firestore_v1_WriteResult>(),
            google_firestore_v1_WriteResult_fields);
}

TEST(FieldsArrayTest, firestore_BundleMetadata) {
  ASSERT_EQ(FieldsArray<firestore_BundleMetadata>(),
            firestore_BundleMetadata_fields);
}

TEST(FieldsArrayTest, firestore_NamedQuery) {
  ASSERT_EQ(FieldsArray<firestore_NamedQuery>(), firestore_NamedQuery_fields);
}

TEST(FieldsArrayTest, google_firestore_admin_v1_Index) {
  ASSERT_EQ(FieldsArray<google_firestore_admin_v1_Index>(),
            google_firestore_admin_v1_Index_fields);
}

TEST(FieldsArrayTest, google_protobuf_Empty) {
  ASSERT_EQ(FieldsArray<google_protobuf_Empty>(), google_protobuf_Empty_fields);
}

TEST(FieldsArrayTest, google_firestore_v1_AggregationResult) {
  ASSERT_EQ(FieldsArray<google_firestore_v1_AggregationResult>(),
            google_firestore_v1_AggregationResult_fields);
}

TEST(FieldsArrayTest, google_firestore_v1_RunAggregationQueryRequest) {
  ASSERT_EQ(FieldsArray<google_firestore_v1_RunAggregationQueryRequest>(),
            google_firestore_v1_RunAggregationQueryRequest_fields);
}

TEST(FieldsArrayTest, google_firestore_v1_RunAggregationQueryResponse) {
  ASSERT_EQ(FieldsArray<google_firestore_v1_RunAggregationQueryResponse>(),
            google_firestore_v1_RunAggregationQueryResponse_fields);
}

TEST(FieldsArrayTest, google_firestore_v1_StructuredAggregationQuery) {
  ASSERT_EQ(FieldsArray<google_firestore_v1_StructuredAggregationQuery>(),
            google_firestore_v1_StructuredAggregationQuery_fields);
}

TEST(FieldsArrayTest,
     google_firestore_v1_StructuredAggregationQuery_Aggregation) {
  ASSERT_EQ(
      FieldsArray<google_firestore_v1_StructuredAggregationQuery_Aggregation>(),
      google_firestore_v1_StructuredAggregationQuery_Aggregation_fields);
}

TEST(FieldsArrayTest,
     google_firestore_v1_StructuredAggregationQuery_Aggregation_Count) {
  ASSERT_EQ(
      FieldsArray<
          google_firestore_v1_StructuredAggregationQuery_Aggregation_Count>(),
      google_firestore_v1_StructuredAggregationQuery_Aggregation_Count_fields);
}

}  //  namespace
}  //  namespace nanopb
}  //  namespace firestore
}  //  namespace firebase
