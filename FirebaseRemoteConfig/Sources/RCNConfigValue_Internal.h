#import "googlemac/iPhone/Config/RemoteConfig/Source/FIRRemoteConfig.h"

@interface FIRRemoteConfigValue ()
@property(nonatomic, readwrite, assign) FIRRemoteConfigSource source;

/// Designated initializer.
- (instancetype)initWithData:(NSData *)data
                      source:(FIRRemoteConfigSource)source NS_DESIGNATED_INITIALIZER;
@end
