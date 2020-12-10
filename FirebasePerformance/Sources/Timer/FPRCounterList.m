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

#import "FirebasePerformance/Sources/Timer/FPRCounterList.h"

@interface FPRCounterList ()

@property(nonatomic) NSMutableDictionary<NSString *, NSNumber *> *counterDictionary;

/** Serial queue to manage incrementing counters. */
@property(nonatomic, readwrite) dispatch_queue_t counterSerialQueue;

@end

@implementation FPRCounterList

- (instancetype)init {
  self = [super init];
  if (self) {
    _counterDictionary = [[NSMutableDictionary alloc] init];
    _counterSerialQueue = dispatch_queue_create("com.google.perf.counters", DISPATCH_QUEUE_SERIAL);
  }
  return self;
}

- (void)incrementCounterNamed:(NSString *)counterName by:(NSInteger)incrementValue {
  dispatch_sync(self.counterSerialQueue, ^{
    if (counterName) {
      NSNumber *number = self.counterDictionary[counterName];
      if (number != nil) {
        int64_t value = [number longLongValue];
        value += incrementValue;
        number = @(value);
      } else {
        number = @(incrementValue);
      }
      self.counterDictionary[counterName] = number;
    }
  });
}

- (NSDictionary *)counters {
  __block NSDictionary *countersDictionary;
  dispatch_sync(self.counterSerialQueue, ^{
    countersDictionary = [self.counterDictionary copy];
  });
  return countersDictionary;
}

- (NSUInteger)numberOfCounters {
  __block NSUInteger numberOfCounters;
  dispatch_sync(self.counterSerialQueue, ^{
    numberOfCounters = self.counterDictionary.count;
  });
  return numberOfCounters;
}

#pragma mark - Methods related to metrics

- (void)incrementMetric:(nonnull NSString *)metricName byInt:(int64_t)incrementValue {
  dispatch_async(self.counterSerialQueue, ^{
    if (metricName) {
      NSNumber *number = self.counterDictionary[metricName];
      if (number != nil) {
        int64_t value = [number longLongValue];
        value += incrementValue;
        number = @(value);
      } else {
        number = @(incrementValue);
      }
      self.counterDictionary[metricName] = number;
    }
  });
}

- (int64_t)valueForIntMetric:(nonnull NSString *)metricName {
  __block int64_t metricValue = 0;
  dispatch_sync(self.counterSerialQueue, ^{
    if (metricName) {
      NSNumber *value = self.counterDictionary[metricName];
      if (value != nil) {
        metricValue = [value longLongValue];
      } else {
        metricValue = 0;
      }
    }
  });
  return metricValue;
}

- (void)deleteMetric:(nonnull NSString *)metricName {
  if (metricName) {
    dispatch_sync(self.counterSerialQueue, ^{
      [self.counterDictionary removeObjectForKey:metricName];
    });
  }
}

- (void)setIntValue:(int64_t)value forMetric:(nonnull NSString *)metricName {
  dispatch_async(self.counterSerialQueue, ^{
    NSNumber *newValue = @(value);
    self.counterDictionary[metricName] = newValue;
  });
}

- (BOOL)isValid {
  // TODO(b/175054970): Rename this class to metrics list and see if this method makes sense.
  return YES;
}

@end
