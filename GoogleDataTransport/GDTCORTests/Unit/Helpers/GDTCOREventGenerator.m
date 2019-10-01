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

#import "GDTCORTests/Unit/Helpers/GDTCOREventGenerator.h"

#import <GoogleDataTransport/GDTCORClock.h>
#import <GoogleDataTransport/GDTCOREvent.h>
#import <GoogleDataTransport/GDTCORStoredEvent.h>

#import "GDTCORLibrary/Private/GDTCOREvent_Private.h"

@implementation GDTCOREventGenerator

+ (NSMutableSet<GDTCORStoredEvent *> *)generate3StoredEvents {
  static NSUInteger counter = 0;
  NSString *cachePath = NSTemporaryDirectory();
  NSString *filePath =
      [cachePath stringByAppendingPathComponent:[NSString stringWithFormat:@"test-%ld.txt",
                                                                           (unsigned long)counter]];
  int howManyToGenerate = 3;
  NSMutableSet<GDTCORStoredEvent *> *set =
      [[NSMutableSet alloc] initWithCapacity:howManyToGenerate];
  for (int i = 0; i < howManyToGenerate; i++) {
    GDTCOREvent *event = [[GDTCOREvent alloc] initWithMappingID:@"1337" target:50];
    event.clockSnapshot = [GDTCORClock snapshot];
    event.qosTier = GDTCOREventQosDefault;
    event.dataObjectTransportBytes = [@"testing!" dataUsingEncoding:NSUTF8StringEncoding];
    [[NSFileManager defaultManager] createFileAtPath:filePath
                                            contents:[NSData data]
                                          attributes:nil];
    GDTCORDataFuture *dataFuture =
        [[GDTCORDataFuture alloc] initWithFileURL:[NSURL fileURLWithPath:filePath]];
    [set addObject:[event storedEventWithDataFuture:dataFuture]];
    counter++;
  }
  return set;
}

@end
