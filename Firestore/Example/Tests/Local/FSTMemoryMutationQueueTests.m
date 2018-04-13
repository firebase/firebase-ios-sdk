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

#import "Firestore/Source/Local/FSTMemoryMutationQueue.h"

#import "Firestore/Source/Auth/FSTUser.h"
#import "Firestore/Source/Local/FSTMemoryPersistence.h"

#import "Firestore/Example/Tests/Local/FSTMutationQueueTests.h"
#import "Firestore/Example/Tests/Local/FSTPersistenceTestHelpers.h"

@interface FSTMemoryMutationQueueTests : FSTMutationQueueTests
@end

/**
 * The tests for FSTMemoryMutationQueue are performed on the FSTMutationQueue protocol in
 * FSTMutationQueueTests. This class is merely responsible for setting up the @a mutationQueue.
 */
@implementation FSTMemoryMutationQueueTests

- (void)setUp {
  [super setUp];

  self.persistence = [FSTPersistenceTestHelpers memoryPersistence];
  self.mutationQueue =
      [self.persistence mutationQueueForUser:[[FSTUser alloc] initWithUID:@"user"]];
}

@end
