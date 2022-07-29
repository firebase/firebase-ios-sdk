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

#import <Foundation/Foundation.h>

#import "FIRAggregateField.h"
#import "FIRAggregateSource.h"
#import "FIRAggregateQuery.h"
#import "FIRAggregateQuerySnapshot.h"
#import "FIRAggregateSnapshot.h"
#import "FIRFieldPath.h"
#import "FIRListenerRegistration.h"
#import "FIRQuery.h"

@interface FIRAggregateDemo : NSObject
@end

@implementation FIRAggregateDemo

+ (void)AggregateFieldTest {
  FIRCountAggregateField* countField1 = [FIRAggregateField aggregateFieldForCount];
  FIRCountAggregateField* countField2 = [FIRAggregateField aggregateFieldForCountUpTo:1000];
  (void)countField1;
  (void)countField2;
  FIRMinAggregateField* minField1 = [FIRAggregateField aggregateFieldForMinOfField:@"field"];
  FIRMinAggregateField* minField2 = [FIRAggregateField aggregateFieldForMinOfFieldPath:[FIRFieldPath documentID]];
  (void)minField1;
  (void)minField2;
  FIRMaxAggregateField* maxField1 = [FIRAggregateField aggregateFieldForMaxOfField:@"field"];
  FIRMaxAggregateField* maxField2 = [FIRAggregateField aggregateFieldForMaxOfFieldPath:[FIRFieldPath documentID]];
  (void)maxField1;
  (void)maxField2;
  FIRSumAggregateField* sumField1 = [FIRAggregateField aggregateFieldForSumOfField:@"field"];
  FIRSumAggregateField* sumField2 = [FIRAggregateField aggregateFieldForSumOfFieldPath:[FIRFieldPath documentID]];
  (void)sumField1;
  (void)sumField2;
  FIRAverageAggregateField* averageField1 = [FIRAggregateField aggregateFieldForAverageOfField:@"field"];
  FIRAverageAggregateField* averageField2 = [FIRAggregateField aggregateFieldForAverageOfFieldPath:[FIRFieldPath documentID]];
  (void)averageField1;
  (void)averageField2;
  FIRFirstAggregateField* firstField1 = [FIRAggregateField aggregateFieldForFirstOfField:@"field"];
  FIRFirstAggregateField* firstField2 = [FIRAggregateField aggregateFieldForFirstOfFieldPath:[FIRFieldPath documentID]];
  (void)firstField1;
  (void)firstField2;
  FIRLastAggregateField* lastField1 = [FIRAggregateField aggregateFieldForLastOfField:@"field"];
  FIRLastAggregateField* lastField2 = [FIRAggregateField aggregateFieldForLastOfFieldPath:[FIRFieldPath documentID]];
  (void)lastField1;
  (void)lastField2;
}

+ (void)QueryTest:(FIRQuery*)query {
  FIRAggregateQuery* aggregateQuery1 = query.countAggregateQuery;
  (void)aggregateQuery1;
  FIRAggregateQuery* aggregateQuery2 = [query aggregateQueryForFields:@[[FIRAggregateField aggregateFieldForCount], [FIRAggregateField aggregateFieldForMaxOfField:@"age"]]];
  (void)aggregateQuery2;
  FIRGroupByQuery* groupByQuery1 = [query groupByQueryForFields:@[@"field1", @"field2"]];
  (void)groupByQuery1;
  FIRGroupByQuery* groupByQuery2 = [query groupByQueryForFieldPaths:@[[FIRFieldPath documentID]]];
  (void)groupByQuery2;
}

+ (void)AggregateQueryTest:(FIRAggregateQuery*)aggregateQuery {
  [aggregateQuery getAggregationWithCompletion:^(FIRAggregateQuerySnapshot *snapshot, NSError *error) {
    NSLog(@"%@ %@", snapshot, error);
  }];
  [aggregateQuery getAggregationWithSource:FIRAggregateSourceServerDirect completion:^(FIRAggregateQuerySnapshot *snapshot, NSError *error) {
    NSLog(@"%@ %@", snapshot, error);
  }];
  id<FIRListenerRegistration> listenerRegistration1 = [aggregateQuery addSnapshotListener:^(FIRAggregateQuerySnapshot *snapshot, NSError *error) {
    NSLog(@"%@ %@", snapshot, error);
  }];
  [listenerRegistration1 remove];
  id<FIRListenerRegistration> listenerRegistration2 = [aggregateQuery addSnapshotListenerWithIncludeMetadataChanges:YES listener:^(FIRAggregateQuerySnapshot *snapshot, NSError *error) {
    NSLog(@"%@ %@", snapshot, error);
  }];
  [listenerRegistration2 remove];
  id<FIRListenerRegistration> listenerRegistration3 = [aggregateQuery addSnapshotListenerWithSource:FIRAggregateListenSourceServerDirect listener:^(FIRAggregateQuerySnapshot *snapshot, NSError *error) {
    NSLog(@"%@ %@", snapshot, error);
  }];
  [listenerRegistration3 remove];
  id<FIRListenerRegistration> listenerRegistration4 = [aggregateQuery addSnapshotListenerWithSource:FIRAggregateListenSourceServerDirect includeMetadataChanges:YES listener:^(FIRAggregateQuerySnapshot *snapshot, NSError *error) {
    NSLog(@"%@ %@", snapshot, error);
  }];
  [listenerRegistration4 remove];
}

+ (void)AggregateQuerySnapshotTest:(FIRAggregateQuerySnapshot*)snapshot {
  FIRAggregateQuery* query = snapshot.query;
  (void)query;
  FIRSnapshotMetadata* metadata = snapshot.metadata;
  (void)metadata;
  id count1 = [snapshot aggregations][[FIRAggregateField aggregateFieldForCount]];
  (void)count1;
  id count2 = [snapshot aggregationsWithServerTimestampBehavior:FIRServerTimestampBehaviorNone][[FIRAggregateField aggregateFieldForCount]];
  (void)count2;
  NSNumber* count3 = [snapshot count];
  (void)count3;
  NSNumber* count4 = [snapshot numberForAggregateField:[FIRAggregateField aggregateFieldForCount]];
  (void)count4;
  NSNumber* count5 = [snapshot numberForAggregateField:[FIRAggregateField aggregateFieldForSumOfField:@"field"]];
  (void)count5;
  NSNumber* count6 = [snapshot numberForAggregateField:[FIRAggregateField aggregateFieldForAverageOfField:@"field"]];
  (void)count6;
  id value1 = [snapshot valueForAggregateField:[FIRAggregateField aggregateFieldForMinOfField:@"field"]];
  (void)value1;
  id value2 = [snapshot valueForAggregateField:[FIRAggregateField aggregateFieldForMinOfField:@"field"] serverTimestampBehavior:FIRServerTimestampBehaviorNone];
  (void)value2;
  id value3 = snapshot[[FIRAggregateField aggregateFieldForMinOfField:@"field"]];
  (void)value3;
}

@end

