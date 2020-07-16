// Copyright 2020 Google LLC
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

#import "GoogleDataTransport/GDTCORLibrary/Internal/GoogleDataTransportInternal.h"

@interface FIRMockGDTCORTransport : GDTCORTransport

NS_ASSUME_NONNULL_BEGIN

@property(nullable, nonatomic, copy) NSString *mappingID;
@property(nonatomic) NSInteger target;

@property(nullable, nonatomic, strong) GDTCOREvent *sendDataEvent_event;
@property(nullable, nonatomic, strong) NSError *sendDataEvent_error;
@property(nonatomic) BOOL sendDataEvent_wasWritten;

- (instancetype)initWithMappingID:(NSString *)mappingID
                     transformers:(nullable NSArray<id<GDTCOREventTransformer>> *)transformers
                           target:(GDTCORTarget)target NS_DESIGNATED_INITIALIZER;

- (void)sendDataEvent:(GDTCOREvent *)event
           onComplete:(nullable void (^)(BOOL wasWritten, NSError *_Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
