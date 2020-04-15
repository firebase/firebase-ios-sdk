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
#import <GoogleDataTransport/GDTCORTargets.h>

#import "GDTCORLibrary/Private/GDTCOREvent_Private.h"
#import "GDTCORTests/Unit/Helpers/GDTCORDataObjectTesterClasses.h"

@implementation GDTCOREventGenerator

+ (NSMutableSet<GDTCOREvent *> *)generate3Events {
  static NSUInteger counter = 0;
  int howManyToGenerate = 3;
  NSMutableSet<GDTCOREvent *> *set = [[NSMutableSet alloc] initWithCapacity:howManyToGenerate];
  for (int i = 0; i < howManyToGenerate; i++) {
    GDTCOREvent *event = [[GDTCOREvent alloc] initWithMappingID:@"1337" target:kGDTCORTargetTest];
    event.clockSnapshot = [GDTCORClock snapshot];
    event.qosTier = GDTCOREventQosDefault;
    event.dataObject = [[GDTCORDataObjectTesterSimple alloc] initWithString:@"testing!"];
    NSString *filePath = [NSString stringWithFormat:@"test-%ld.txt", (unsigned long)counter];
    [[NSFileManager defaultManager] createFileAtPath:filePath
                                            contents:[NSData data]
                                          attributes:nil];
    NSError *error = nil;
    [event writeToGDTPath:filePath error:&error];
    [set addObject:event];
    counter++;
  }
  return set;
}

@end
