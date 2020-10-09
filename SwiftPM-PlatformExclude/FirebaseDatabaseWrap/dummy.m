#import <TargetConditionals.h>
#if TARGET_OS_WATCH
#warning "Firebase Database does not support watchOS"
#endif
