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

#import "GDTCCTEventGenerator.h"

@implementation GDTCCTEventGenerator

- (void)deleteGeneratedFilesFromDisk {
  for (GDTStoredEvent *storedEvent in self.allGeneratedEvents) {
    NSError *error;
    [[NSFileManager defaultManager] removeItemAtURL:storedEvent.eventFileURL error:&error];
    NSAssert(error == nil, @"There was an error deleting a temporary event file.");
  }
}

- (GDTStoredEvent *)generateStoredEvent:(GDTEventQoS)qosTier {
  static NSUInteger counter = 0;
  NSString *cachePath = NSTemporaryDirectory();
  NSString *filePath =
      [cachePath stringByAppendingPathComponent:[NSString stringWithFormat:@"test-%ld.txt",
                                                                           (unsigned long)counter]];
  GDTEvent *event = [[GDTEvent alloc] initWithMappingID:@"1337" target:50];
  event.clockSnapshot = [GDTClock snapshot];
  event.qosTier = qosTier;
  [[NSFileManager defaultManager] createFileAtPath:filePath contents:[NSData data] attributes:nil];
  counter++;
  GDTStoredEvent *storedEvent = [event storedEventWithFileURL:[NSURL fileURLWithPath:filePath]];
  [self.allGeneratedEvents addObject:storedEvent];
  return storedEvent;
}

@end
