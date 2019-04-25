/*
 * Copyright 2019 Google
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

#import "GDTTests/Unit/Helpers/GDTEventGenerator.h"

#import <GoogleDataTransport/GDTClock.h>
#import <GoogleDataTransport/GDTEvent.h>
#import <GoogleDataTransport/GDTStoredEvent.h>

#import "GDTLibrary/Private/GDTEvent_Private.h"

@implementation GDTEventGenerator

+ (NSMutableSet<GDTStoredEvent *> *)generate3StoredEvents {
  static NSUInteger counter = 0;
  NSString *cachePath = NSTemporaryDirectory();
  NSString *filePath =
      [cachePath stringByAppendingPathComponent:[NSString stringWithFormat:@"test-%ld.txt",
                                                                           (unsigned long)counter]];
  int howManyToGenerate = 3;
  NSMutableSet<GDTStoredEvent *> *set = [[NSMutableSet alloc] initWithCapacity:howManyToGenerate];
  for (int i = 0; i < howManyToGenerate; i++) {
    GDTEvent *event = [[GDTEvent alloc] initWithMappingID:@"1337" target:50];
    event.clockSnapshot = [GDTClock snapshot];
    event.qosTier = GDTEventQosDefault;
    event.dataObjectTransportBytes = [@"testing!" dataUsingEncoding:NSUTF8StringEncoding];
    [[NSFileManager defaultManager] createFileAtPath:filePath
                                            contents:[NSData data]
                                          attributes:nil];
    GDTDataFuture *dataFuture =
        [[GDTDataFuture alloc] initWithFileURL:[NSURL fileURLWithPath:filePath]];
    [set addObject:[event storedEventWithDataFuture:dataFuture]];
    counter++;
  }
  return set;
}

@end
