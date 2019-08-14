#import "googlemac/iPhone/Config/RemoteConfig/Source/FIRRemoteConfig.h"

#import "googlemac/iPhone/Config/RemoteConfig/Source/RCNConfigValue_Internal.h"
#import "third_party/firebase/ios/Releases/FirebaseCore/Library/Private/FIRLogger.h"

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
