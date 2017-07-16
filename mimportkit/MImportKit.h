#import <stdlib.h>
#import <unistd.h>
#import <stdint.h>
#import <stdio.h>
#import <sys/stat.h>
#import <sys/types.h>
#import <Foundation/Foundation.h>
#import <AppSupport/CPDistributedMessagingCenter.h>

#define NSLog(...)

@interface _UIDocumentActivityItemProvider : NSObject
@property (nonatomic, copy) _UIDocumentActivityItemProvider *asset;
- (id)item;
- (id)mainFileURL;
- (id)mediaPath; //NSString
- (id)itemURL; //url
@end

@interface UIOpenWithAppActivityClass : UIActivity
@property (assign) BOOL isMImport;
- (id)initWithApplicationIdentifier:(id)arg1 documentInteractionController:(id)arg2;
- (id)initWithApplicationIdentifier:(id)arg1 documentInteractionController:(id)arg2 appIsOwner:(bool)arg3; // iOS 10
@end

@interface UIActivityViewController (gg)
@property (nonatomic, copy) NSArray *activityItems;
@end
