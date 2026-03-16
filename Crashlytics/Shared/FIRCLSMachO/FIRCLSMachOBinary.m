// Copyright 2019 Google
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

#import "Crashlytics/Shared/FIRCLSMachO/FIRCLSMachOBinary.h"

#import <CommonCrypto/CommonHMAC.h>
#import "Crashlytics/Crashlytics/Helpers/FIRCLSUtility.h"
#import "Crashlytics/Shared/FIRCLSByteUtility.h"
#import "Crashlytics/Shared/FIRCLSMachO/FIRCLSMachOSlice.h"

static NSString* FIRCLSHashNSString(NSString* value);

@interface FIRCLSMachOBinary ()

+ (NSString*)hashNSString:(NSString*)value;

@end

@implementation FIRCLSMachOBinary

+ (id)MachOBinaryWithPath:(NSString*)path {
  return [[self alloc] initWithURL:[NSURL fileURLWithPath:path]];
}

@synthesize slices = _slices;

- (id)initWithURL:(NSURL*)url {
  self = [super init];
  if (self) {
    _url = [url copy];

    if (!FIRCLSMachOFileInitWithPath(&_file, [[_url path] fileSystemRepresentation])) {
      return nil;
    }

    _slices = [NSMutableArray new];
    FIRCLSMachOFileEnumerateSlices(&_file, ^(FIRCLSMachOSliceRef slice) {
      FIRCLSMachOSlice* sliceObject;

      sliceObject = [[FIRCLSMachOSlice alloc] initWithSlice:slice];

      [self->_slices addObject:sliceObject];
    });
  }

  return self;
}

- (void)dealloc {
  FIRCLSMachOFileDestroy(&_file);
}

- (NSURL*)URL {
  return _url;
}

- (NSString*)path {
  return [_url path];
}

- (NSString*)instanceIdentifier {
  if (_instanceIdentifier) {
    return _instanceIdentifier;
  }

  NSMutableString* prehashedString = [NSMutableString new];

  // sort the slices by architecture
  NSArray* sortedSlices =
      [_slices sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        return [[obj1 architectureName] compare:[obj2 architectureName]];
      }];

  // append them all into a big string
  for (FIRCLSMachOSlice* slice in sortedSlices) {
    [prehashedString appendString:[slice uuid]];
  }

  _instanceIdentifier = [FIRCLSHashNSString(prehashedString) copy];

  return _instanceIdentifier;
}

- (void)enumerateUUIDs:(void (^)(NSString* uuid, NSString* architecture))block {
  for (FIRCLSMachOSlice* slice in _slices) {
    block([slice uuid], [slice architectureName]);
  }
}

- (FIRCLSMachOSlice*)sliceForArchitecture:(NSString*)architecture {
  for (FIRCLSMachOSlice* slice in [self slices]) {
    if ([[slice architectureName] isEqualToString:architecture]) {
      return slice;
    }
  }

  return nil;
}

+ (NSString*)hashNSString:(NSString*)value {
  return FIRCLSHashNSString(value);
}

@end

static NSString* FIRCLSHashNSString(NSString* value) {
  const char* s = [value cStringUsingEncoding:NSUTF8StringEncoding];

  return FIRCLSHashBytes(s, strlen(s));
}
