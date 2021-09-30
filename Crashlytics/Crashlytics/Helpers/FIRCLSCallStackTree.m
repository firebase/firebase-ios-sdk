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

#import <Foundation/Foundation.h>

#import "Crashlytics/Crashlytics/Helpers/FIRCLSCallStackTree.h"

#if CLS_METRICKIT_SUPPORTED

@interface FIRCLSFrame : NSObject
@property long address;
@property long sampleCount;
@property long offsetIntoBinaryTextSegment;
@property NSString *binaryName;
@property NSUUID *binaryUUID;
@end

@implementation FIRCLSFrame
@end

@interface FIRCLSThread : NSObject
@property NSString *threadName;
@property BOOL threadBlamed;
@property NSArray<FIRCLSFrame *> *frames;
@end

@implementation FIRCLSThread
@end

@interface FIRCLSCallStackTree ()
@property NSArray<FIRCLSThread *> *threads;
@property(nonatomic) BOOL callStackPerThread;

@end

@implementation FIRCLSCallStackTree

- (instancetype)initWithMXCallStackTree:(MXCallStackTree *)callStackTree {
  NSData *jsonCallStackTree = callStackTree.JSONRepresentation;
  if ([jsonCallStackTree length] == 0) return nil;

  NSError *error = nil;
  NSDictionary *jsonDictionary = [NSJSONSerialization JSONObjectWithData:jsonCallStackTree
                                                                 options:0
                                                                   error:&error];
  if (error) {
    NSLog(@"Crashlytics: error creating json");
    return nil;
  }
  self = [super init];
  if (!self) {
    return nil;
  }
  _callStackPerThread = [[jsonDictionary objectForKey:@"callStackPerThread"] boolValue];

  // Recurse through the frames in the callStackTree and add them all to an array
  NSMutableArray<FIRCLSThread *> *threads = [[NSMutableArray alloc] init];
  NSArray *callStacks = jsonDictionary[@"callStacks"];
  for (id object in callStacks) {
    NSMutableArray<FIRCLSFrame *> *frames = [[NSMutableArray alloc] init];
    [self flattenSubFrames:object[@"callStackRootFrames"] intoFrames:frames];
    FIRCLSThread *thread = [[FIRCLSThread alloc] init];
    thread.threadBlamed = [[object objectForKey:@"threadAttributed"] boolValue];
    thread.frames = frames;
    [threads addObject:thread];
  }
  _threads = threads;
  return self;
}

// Flattens the nested structure we receive from MetricKit into an array of frames.
- (void)flattenSubFrames:(NSArray *)callStacks intoFrames:(NSMutableArray *)frames {
  NSDictionary *rootFrames = [callStacks firstObject];
  FIRCLSFrame *frame = [[FIRCLSFrame alloc] init];
  frame.offsetIntoBinaryTextSegment =
      [[rootFrames valueForKey:@"offsetIntoBinaryTextSegment"] longValue];
  frame.address = [[rootFrames valueForKey:@"address"] longValue];
  frame.sampleCount = [[rootFrames valueForKey:@"sampleCount"] longValue];
  frame.binaryUUID = [rootFrames valueForKey:@"binaryUUID"];
  frame.binaryName = [rootFrames valueForKey:@"binaryName"];

  [frames addObject:frame];

  // Recurse through any subframes and add them to the array.
  if ([rootFrames objectForKey:@"subFrames"]) {
    [self flattenSubFrames:[rootFrames objectForKey:@"subFrames"] intoFrames:frames];
  }
}

- (NSArray *)getArrayRepresentation {
  NSMutableArray *threadArray = [[NSMutableArray alloc] init];
  for (FIRCLSThread *thread in self.threads) {
    [threadArray addObject:[self getDictionaryRepresentation:thread]];
  }
  return threadArray;
}

- (NSDictionary *)getDictionaryRepresentation:(FIRCLSThread *)thread {
  NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] init];
  [dictionary setObject:@{} forKey:@"registers"];
  NSMutableArray *frameArray = [[NSMutableArray alloc] init];
  for (FIRCLSFrame *frame in thread.frames) {
    [frameArray addObject:[NSNumber numberWithLong:frame.address]];
  }
  [dictionary setObject:frameArray forKey:@"stacktrace"];
  [dictionary setObject:[NSNumber numberWithBool:thread.threadBlamed] forKey:@"crashed"];
  return dictionary;
}

- (NSArray *)getFramesOfBlamedThread {
  for (FIRCLSThread *thread in self.threads) {
    if (thread.threadBlamed) {
      return [self convertFramesFor:thread];
    }
  }
  if ([self.threads count] > 0) {
    return [self convertFramesFor:self.threads.firstObject];
  }
  return [NSArray array];
}

- (NSArray *)convertFramesFor:(FIRCLSThread *)thread {
  NSMutableArray *frames = [[NSMutableArray alloc] init];
  for (FIRCLSFrame *frame in thread.frames) {
    [frames addObject:@{
      @"pc" : [NSNumber numberWithLong:frame.address],
      @"offset" : [NSNumber numberWithLong:frame.offsetIntoBinaryTextSegment],
      @"line" : @0
    }];
  }
  return frames;
}

@end

#endif
