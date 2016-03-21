#import <stdlib.h>
#import <unistd.h>
#import <stdint.h>
#import <stdio.h>
#import <sys/stat.h>
#import <sys/types.h>
#import <Foundation/Foundation.h>
#import <AppSupport/CPDistributedMessagingCenter.h>


@interface MImportCenter : NSObject
{
	CPDistributedMessagingCenter *center;
	NSFileManager *fileManager;
}
- (NSDictionary *)handleMessageNamed:(NSString *)name userInfo:(NSDictionary *)info;
- (void)loadCenter;
@end
