// Copyright 2020 Google
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

#import <GoogleDataTransport/GDTCORTransport.h>

@interface FIRMockGDTCORTransport : GDTCORTransport

@property(nonatomic, copy) NSString *mappingID;
@property(nonatomic) NSInteger target;

@property(nonatomic, strong) GDTCOREvent *sendDataEvent_event;
@property(nonatomic, strong) NSError *sendDataEvent_error;
@property(nonatomic) BOOL sendDataEvent_wasWritten;

- (instancetype)initWithMappingID:(NSString *)mappingID
                     transformers:(NSArray<id<GDTCOREventTransformer>> *)transformers
                           target:(NSInteger)target NS_DESIGNATED_INITIALIZER;

- (void)sendDataEvent:(GDTCOREvent *)event
           onComplete:(void (^)(BOOL wasWritten, NSError *error))completion;

@end
