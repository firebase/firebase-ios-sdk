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

#import "Crashlytics/UnitTests/Mocks/FIRMockGDTCoreTransport.h"

@implementation FIRMockGDTCORTransport

- (instancetype)initWithMappingID:(NSString *)mappingID
                     transformers:(nullable NSArray<id<GDTCOREventTransformer>> *)transformers
                           target:(GDTCORTarget)target {
  _mappingID = mappingID;
  _target = target;
  _sendDataEvent_wasWritten = YES;
  _async = NO;

  return [super initWithMappingID:mappingID transformers:transformers target:target];
}

- (void)sendDataEvent:(GDTCOREvent *)event
           onComplete:(void (^)(BOOL wasWritten, NSError *error))completion {
  dispatch_block_t sendData = ^() {
    self.sendDataEvent_event = event;
    completion(self.sendDataEvent_wasWritten, self.sendDataEvent_error);
  };

  if (self.async) {
    dispatch_after(DISPATCH_TIME_NOW, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
                   sendData);
  } else {
    sendData();
  }
}

@end
