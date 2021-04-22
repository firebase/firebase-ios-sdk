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

#import <FirebaseFirestore/FIRQuery.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^FIRFirestoreGetDocumentsHandler)(FIRQuerySnapshotBlock completion);

/// A fake object to replace a real `Query` in tests.
NS_SWIFT_NAME(QueryFake)
@interface FIRQueryFake : FIRQuery

- (instancetype)init;

/// The block to be called each time when `getDocuments(completion:)` method is called.
@property(nonatomic, nullable, copy) FIRFirestoreGetDocumentsHandler getDocumentsHandler;

// TODO: Implement other handlers as needed.

@end

NS_ASSUME_NONNULL_END
