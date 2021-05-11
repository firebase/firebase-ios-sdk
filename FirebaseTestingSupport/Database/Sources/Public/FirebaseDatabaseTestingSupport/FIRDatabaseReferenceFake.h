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

#import <FirebaseDatabase/FIRDatabaseReference.h>

NS_ASSUME_NONNULL_BEGIN

/// A fake object to replace a real `DatabaseReference` in tests.
NS_SWIFT_NAME(DatabaseReferenceFake)
@interface FIRDatabaseReferenceFake : FIRDatabaseReference
- (instancetype)init;

@property(nonatomic, nullable, copy) void (^callbackBlock)(FIRDataSnapshot *_Nonnull __strong);

@property(nonatomic, nullable, copy) id value;

- (void)setValue:(nullable id)value
    withCompletionBlock:(nonnull void (^)(NSError *_Nullable __strong,
                                          FIRDatabaseReference *_Nonnull __strong))block;

- (void)observeSingleEventOfType:(FIRDataEventType)eventType
                       withBlock:(nonnull void (^)(FIRDataSnapshot *_Nonnull __strong))block;

- (FIRDatabaseHandle)observeEventType:(FIRDataEventType)eventType
                            withBlock:(nonnull void (^)(FIRDataSnapshot *_Nonnull __strong))block;

- (void)removeObserverWithHandle:(FIRDatabaseHandle)handle;

@end

NS_ASSUME_NONNULL_END
