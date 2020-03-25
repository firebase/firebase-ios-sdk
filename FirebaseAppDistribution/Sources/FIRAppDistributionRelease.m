#import "FIRAppDistributionRelease.h"

@implementation FIRAppDistributionRelease
- (instancetype)init {
    self = [super init];
    
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    self = [super init];
    if(self) {
        NSLog(@"Release init dict %@", dict);
        self.buildVersion = [dict objectForKey:@"buildVersion"];
        self.displayVersion = [dict objectForKey:@"displayVersion"];
        
        self.downloadURL = [[NSURL alloc] initWithString:[dict objectForKey:@"downloadUrl"]];
        self.releaseNotes = [dict objectForKey:@"releaseNotes"];
    }
    return self;
}
@end
