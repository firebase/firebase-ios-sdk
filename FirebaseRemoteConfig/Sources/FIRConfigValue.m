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

#import "FirebaseRemoteConfig/Sources/Public/FirebaseRemoteConfig/FIRRemoteConfig.h"

#import "FirebaseCore/Extension/FirebaseCoreInternal.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigValue_Internal.h"

@implementation FIRRemoteConfigValue {
  /// Data backing the config value.
  NSData *_data;
  FIRRemoteConfigSource _source;
}

/// Designated initializer
- (instancetype)initWithData:(NSData *)data source:(FIRRemoteConfigSource)source {
  self = [super init];
  if (self) {
    _data = [data copy];
    _source = source;
  }
  return self;
}

/// Superclass's designated initializer
- (instancetype)init {
  return [self initWithData:nil source:FIRRemoteConfigSourceStatic];
}

/// The string is a UTF-8 representation of NSData.
- (NSString *)stringValue {
  return [[NSString alloc] initWithData:_data encoding:NSUTF8StringEncoding];
}

/// Number representation of a UTF-8 string.
- (NSNumber *)numberValue {
  return [NSNumber numberWithDouble:self.stringValue.doubleValue];
}

/// Internal representation of the FIRRemoteConfigValue as a NSData object.
- (NSData *)dataValue {
  return _data;
}

/// Boolean representation of a UTF-8 string.
- (BOOL)boolValue {
  return self.stringValue.boolValue;
}

/// Returns a foundation object (NSDictionary / NSArray) representation for JSON data.
- (id)JSONValue {
  NSError *error;
  if (!_data) {
    return nil;
  }
  id JSONObject = [NSJSONSerialization JSONObjectWithData:_data options:kNilOptions error:&error];
  if (error) {
    FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000065", @"Error parsing data as JSON.");
    return nil;
  }
  return JSONObject;
}

/// Debug description showing the representations of all types.
- (NSString *)debugDescription {
  NSString *content = [NSString
      stringWithFormat:@"Boolean: %d, String: %@, Number: %@, JSON:%@, Data: %@, Source: %zd",
                       self.boolValue, self.stringValue, self.numberValue, self.JSONValue, _data,
                       (long)self.source];
  return [NSString stringWithFormat:@"<%@: %p, %@>", [self class], self, content];
}

/// Copy method.
- (id)copyWithZone:(NSZone *)zone {
  FIRRemoteConfigValue *value = [[[self class] allocWithZone:zone] initWithData:_data];
  return value;
}
@end
