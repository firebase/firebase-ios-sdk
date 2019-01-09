//
//  AppDelegate.m
//  macOS_example
//
//  Created by Paul Harter on 09/01/2019.
//

#import "AppDelegate.h"
#import "FirebaseCore.h"
#import "FirebaseFirestore.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
    // create a firestore db
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"GoogleService-Info" ofType:@"plist"];
    FIROptions *options = [[FIROptions alloc] initWithContentsOfFile:filePath];
    [FIRApp configureWithOptions:options];
    FIRFirestore *db = [FIRFirestore firestore];
    
    // do the timestamp fix
    FIRFirestoreSettings* settings = db.settings;
    settings.timestampsInSnapshotsEnabled = true;
    db.settings = settings;
    
    // create a doc
    FIRDocumentReference* docRef = [[db collectionWithPath:@"junk"] documentWithPath:@"test_doc"];
    NSDictionary* data = @{@"msg": @"hello"};

    [docRef setData:data completion:^(NSError * _Nullable error) {
        if (error != nil) {
            NSLog(@"created error: %@", error);
        } else {
            NSLog(@"Yay!");
        }
    }];
    
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


@end
