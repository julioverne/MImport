#import <stdlib.h>
#import <unistd.h>
#import <stdint.h>
#import <stdio.h>
#import <sys/stat.h>
#import <sys/types.h>
#import <dlfcn.h>
#import <Foundation/Foundation.h>
#import <AppSupport/CPDistributedMessagingCenter.h>
#import <AudioToolbox/AudioToolbox.h>

enum {
  fileOperationNone             = 0,
  fileOperationDelete           = 1, 
  fileOperationMove             = 2,
  fileOperationExtract          = 3,
  fileOperationCopy             = 4,
};

@interface LSApplicationProxy : NSObject
@property (nonatomic, readonly) long bundleModTime;
@property (nonatomic, readonly) NSString *applicationIdentifier;
@property (nonatomic, readonly) NSDictionary *entitlements;
@property (nonatomic, readonly) NSString *signerIdentity;
@property (nonatomic, readonly) BOOL profileValidated;
@property (nonatomic, readonly) NSString *shortVersionString;
@property (nonatomic, readonly) NSNumber *staticDiskUsage;
@property (nonatomic, readonly) NSString *teamID;
@property (nonatomic, readonly) NSURL *bundleURL;
@property (nonatomic, readonly) NSURL *dataContainerURL;
+ (id)applicationProxyForIdentifier:(id)arg1;
- (BOOL)isSystemOrInternalApp;
- (id)localizedName;
@end

@interface LSApplicationWorkspace : NSObject
+ (id)defaultWorkspace;
- (id)allInstalledApplications;
@end