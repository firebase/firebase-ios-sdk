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

#import "FirebaseTestingSupport/Firestore/Sources/Public/FirebaseFirestoreTestingSupport/FIRQueryFake.h"

@implementation FIRQueryFake

- (instancetype)init {
  // The object is partially initialized. Make sure the methods used during testing are overridden.
  return self;
}

- (void)getDocumentsWithCompletion:(FIRQuerySnapshotBlock)completion {
  if (self.getDocumentsHandler) {
    self.getDocumentsHandler(completion);
  }
}

@end
