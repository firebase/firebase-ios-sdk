// Copyright 2017 Google
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

#import "Functions/FirebaseFunctions/FUNSerializer.h"

#import "Functions/FirebaseFunctions/FUNUsageValidation.h"
#import "Functions/FirebaseFunctions/Public/FirebaseFunctions/FIRError.h"

NS_ASSUME_NONNULL_BEGIN

static NSString *const kLongType = @"type.googleapis.com/google.protobuf.Int64Value";
static NSString *const kUnsignedLongType = @"type.googleapis.com/google.protobuf.UInt64Value";
static NSString *const kDateType = @"type.googleapis.com/google.protobuf.Timestamp";

@interface FUNSerializer () {
  NSDateFormatter *_dateFormatter;
}
@end

@implementation FUNSerializer

- (instancetype)init {
  self = [super init];
  if (self) {
    _dateFormatter = [[NSDateFormatter alloc] init];
    _dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'";
    _dateFormatter.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
  }
  return self;
}

- (id)encodeNumber:(NSNumber *)number {
  // Recover the underlying type of the number, using the method described here:
  // http://stackoverflow.com/questions/2518761/get-type-of-nsnumber
  const char *cType = [number objCType];

  // Type Encoding values taken from
  // https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/
  // Articles/ocrtTypeEncodings.html
  switch (cType[0]) {
    case 'q':
      // "long long" might be larger than JS supports, so make it a string.
      return @{
        @"@type" : kLongType,
        @"value" : [NSString stringWithFormat:@"%@", number],
      };
    case 'Q':
      // "unsigned long long" might be larger than JS supports, so make it a string.
      return @{
        @"@type" : kUnsignedLongType,
        @"value" : [NSString stringWithFormat:@"%@", number],
      };

    case 'i':
    case 's':
    case 'l':
    case 'I':
    case 'S':
      // If it's an integer that isn't too long, so just use the number.
      return number;

    case 'f':
    case 'd':
      // It's a float/double that's not too large.
      return number;

    case 'B':
    case 'c':
    case 'C':
      // Boolean values are weird.
      //
      // On arm64, objCType of a BOOL-valued NSNumber will be "c", even though @encode(BOOL)
      // returns "B". "c" is the same as @encode(signed char). Unfortunately this means that
      // legitimate usage of signed chars is impossible, but this should be rare.
      //
      // Just return Boolean values as-is.
      return number;

    default:
      // All documented codes should be handled above, so this shouldn't happen.
      FUNThrowInvalidArgument(@"Unknown NSNumber objCType %s on %@", cType, number);
  }
}

- (id)encode:(id)object {
  if ([object isEqual:[NSNull null]]) {
    return object;
  }
  if ([object isKindOfClass:[NSNumber class]]) {
    return [self encodeNumber:object];
  }
  if ([object isKindOfClass:[NSString class]]) {
    return object;
  }
  if ([object isKindOfClass:[NSDictionary class]]) {
    NSMutableDictionary *encoded = [NSMutableDictionary dictionary];
    [object
        enumerateKeysAndObjectsUsingBlock:^(id _Nonnull key, id _Nonnull obj, BOOL *_Nonnull stop) {
          encoded[key] = [self encode:obj];
        }];
    return encoded;
  }
  if ([object isKindOfClass:[NSArray class]]) {
    NSMutableArray *encoded = [NSMutableArray arrayWithCapacity:[object count]];
    for (id obj in object) {
      [encoded addObject:[self encode:obj]];
    }
    return encoded;
  }
  // TODO(klimt): Add this back when we support NSDate.
  /*
  if ([object isKindOfClass:[NSDate class]]) {
    NSString *iso8601 = [_dateFormatter stringFromDate:object];
    return @{
      @"@type" : kDateType,
      @"value" : iso8601,
    };
  }
  */
  FUNThrowInvalidArgument(@"Unsupported type: %@ for value %@", NSStringFromClass([object class]),
                          object);
}

NSError *FUNInvalidNumberError(id value, id wrapped) {
  NSString *description = [NSString stringWithFormat:@"Invalid number: %@ for %@", value, wrapped];
  NSDictionary *userInfo = @{
    NSLocalizedDescriptionKey : description,
  };
  return [NSError errorWithDomain:FIRFunctionsErrorDomain
                             code:FIRFunctionsErrorCodeInternal
                         userInfo:userInfo];
}

- (nullable id)decodeWrappedType:(NSDictionary *)wrapped error:(NSError **)error {
  NSAssert(error, @"error must not be nil");
  NSString *type = wrapped[@"@type"];
  NSString *value = wrapped[@"value"];
  if (!value) {
    return nil;
  }
  if ([type isEqualToString:kLongType]) {
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    NSNumber *n = [formatter numberFromString:value];
    if (n == nil) {
      if (error != NULL) {
        *error = FUNInvalidNumberError(value, wrapped);
      }
      return nil;
    }
    return n;
  } else if ([type isEqualToString:kUnsignedLongType]) {
    // NSNumber formatter doesn't handle unsigned long long, so we have to parse it.
    const char *str = value.UTF8String;
    char *end = NULL;
    unsigned long long n = strtoull(str, &end, 10);
    if (errno == ERANGE) {
      // This number was actually too big for an unsigned long long.
      if (error != NULL) {
        *error = FUNInvalidNumberError(value, wrapped);
      }
      return nil;
    }
    if (*end) {
      // The whole string wasn't parsed.
      if (error != NULL) {
        *error = FUNInvalidNumberError(value, wrapped);
      }
      return nil;
    }
    return @(n);
  }
  return nil;
}

- (nullable id)decode:(id)object error:(NSError **)error {
  NSAssert(error, @"error must not be nil");
  if ([object isKindOfClass:[NSDictionary class]]) {
    if (object[@"@type"]) {
      id result = [self decodeWrappedType:object error:error];
      if (*error) {
        return nil;
      }
      if (result) {
        return result;
      }
      // Treat unknown types as dictionaries, so we don't crash old clients when we add types.
    }
    NSMutableDictionary *decoded = [NSMutableDictionary dictionary];
    __block NSError *decodeError = nil;
    [object
        enumerateKeysAndObjectsUsingBlock:^(id _Nonnull key, id _Nonnull obj, BOOL *_Nonnull stop) {
          id decodedItem = [self decode:obj error:&decodeError];
          if (decodeError) {
            *stop = YES;
            return;
          }
          decoded[key] = decodedItem;
        }];
    if (decodeError) {
      if (error != NULL) {
        *error = decodeError;
      }
      return nil;
    }
    return decoded;
  }
  if ([object isKindOfClass:[NSArray class]]) {
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:[object count]];
    for (id obj in object) {
      id decoded = [self decode:obj error:error];
      if (*error) {
        return nil;
      }
      [result addObject:decoded];
    }
    return result;
  }
  if ([object isKindOfClass:[NSNumber class]] || [object isKindOfClass:[NSString class]] ||
      [object isEqual:[NSNull null]]) {
    return object;
  }
  FUNThrowInvalidArgument(@"Unsupported type: %@ for value %@", NSStringFromClass([object class]),
                          object);
}

@end

NS_ASSUME_NONNULL_END
