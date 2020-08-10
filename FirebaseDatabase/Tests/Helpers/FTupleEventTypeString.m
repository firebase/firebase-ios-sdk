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

#import "FirebaseDatabase/Tests/Helpers/FTupleEventTypeString.h"

@implementation FTupleEventTypeString

@synthesize firebase;
@synthesize eventType;
@synthesize string;
@synthesize vvcallback;
@synthesize initialized;

- (id)initWithFirebase:(FIRDatabaseReference *)f
             withEvent:(FIRDataEventType)evt
            withString:(NSString *)str;
{
  self = [super init];
  if (self) {
    self.firebase = f;
    self.eventType = evt;
    self.string = str;
    self.initialized = NO;
  }
  return self;
}

- (NSString *)description {
  return [NSString stringWithFormat:@"%@ %@ (%zd)", self.firebase, self.string, self.eventType];
}

- (BOOL)isEqualTo:(FTupleEventTypeString *)other {
  BOOL stringsEqual = NO;
  if (self.string == nil && other.string == nil) {
    stringsEqual = YES;
  } else if (self.string != nil && other.string != nil) {
    stringsEqual = [self.string isEqualToString:other.string];
  }
  return self.eventType == other.eventType && stringsEqual &&
         [[self.firebase description] isEqualToString:[other.firebase description]];
}

@end
