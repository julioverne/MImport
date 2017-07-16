#import <stdlib.h>
#import <unistd.h>
#import <stdint.h>
#import <stdio.h>
#import <sys/stat.h>
#import <sys/types.h>
#import <dlfcn.h>
#import <Foundation/Foundation.h>
#import <AppSupport/CPDistributedMessagingCenter.h>

#define NSLog(...)


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