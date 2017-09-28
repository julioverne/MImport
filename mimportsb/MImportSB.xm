#import "MImportSB.h"

#define NSLog(...)

#import "../libMImportWebServer/MImportWebServer.h"
#import "../libMImportWebServer/MImportWebServerFileResponse.h"
#import "../libMImportWebServer/MImportWebServerDataRequest.h"
#import "../libMImportWebServer/MImportWebServerDataResponse.h"

#define PORT_SERVER 4194
#define kMaxIdleTimeSeconds 2
#define SERVER_TIMEOUT_SECONDS 3600


static __strong MImportWebServer* _webServer;

const char* mimport_running = "/private/var/mobile/Media/mimport_running";
#define MIMPORT_CACHE_URL "/private/var/mobile/Media/mImportCache.plist"

static void disableServerAndCleanCache(BOOL cleanCache)
{
	unlink(mimport_running);
	if(cleanCache) {
		[[NSFileManager defaultManager] removeItemAtPath:@MIMPORT_CACHE_URL error:nil];
	}
}

static int isFileZipAtPath(NSString* path)
{
	@autoreleasepool {
		if(path) {
			if(NSFileHandle *fh = [NSFileHandle fileHandleForReadingAtPath:path]) {
				NSData *data = [fh readDataOfLength:4];
				if (data && [data length] == 4) {
					const char *bytes = (const char *)[data bytes];
					if(bytes[0] == 'P' && bytes[1] == 'K' && bytes[2] == 3 && bytes[3] == 4) {
						return 1;
					}
					if(bytes[0] == 'R' && bytes[1] == 'a' && bytes[2] == 'r' && bytes[3] == '!') {
						return 2;
					}
				}
			}
		}
		return 0;
	}
}

@interface SpringBoard : NSObject
- (void)mimportAllocServer;
@end

@interface MImportServer : NSObject
+(MImportServer*)shared;
- (void)resetTimeOutCheck;
@end
@implementation MImportServer
+(MImportServer*)shared
{
	static MImportServer* shard = nil;
	if(!shard) {
		shard = [[[self class] alloc] init];
	}
	return shard;
}
- (void)resetTimeOutCheck
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(mimportTimeoutServer) object:nil];
	[self performSelector:@selector(mimportTimeoutServer) withObject:nil afterDelay:SERVER_TIMEOUT_SECONDS];
}
- (void)mimportTimeoutServer
{
	disableServerAndCleanCache(YES);
}
@end

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application
{
    %orig;
	disableServerAndCleanCache(NO);
	[NSTimer scheduledTimerWithTimeInterval:kMaxIdleTimeSeconds target:self selector:@selector(mimportChecker) userInfo:nil repeats:YES];
}
%new
- (void)mimportAllocServer
{
	if(_webServer) {
		return;
	}
	dlopen("/usr/lib/libMImportWebServer.dylib", RTLD_LAZY | RTLD_GLOBAL);
	_webServer = [[objc_getClass("MImportWebServer") alloc] init];
	
	
	
	[_webServer addDefaultHandlerForMethod:@"GET" requestClass:objc_getClass("MImportWebServerRequest") processBlock:^MImportWebServerResponse *(MImportWebServerRequest* request) {
		
		[[MImportServer shared] resetTimeOutCheck];
		
		NSURL* url = request.URL;
		NSDictionary* cachedUrls = [[NSDictionary alloc] initWithContentsOfFile:@MIMPORT_CACHE_URL]?:@{};
		if(NSString * urlFromMD5St = cachedUrls[[[url lastPathComponent] stringByDeletingPathExtension]]) {
			if(NSURL* urlFromMD5 = [NSURL URLWithString:urlFromMD5St]) {
				if([urlFromMD5 isFileURL]) {
					NSString* fileR = [urlFromMD5 path];
					if(fileR && [[NSFileManager defaultManager] fileExistsAtPath:fileR]) {
						return [objc_getClass("MImportWebServerFileResponse") responseWithFile:fileR byteRange:request.byteRange];
					}
				} else {
					NSLog(@"*** REDIRECT REQUEST TO: %@", urlFromMD5);
					return [objc_getClass("MImportWebServerResponse") responseWithRedirect:urlFromMD5 permanent:NO];
				}
			}
		}
		return [objc_getClass("MImportWebServerDataResponse") responseWithData:[NSData data] contentType:@"data"];
	}];
	[_webServer addDefaultHandlerForMethod:@"POST" requestClass:objc_getClass("MImportWebServerRequest") processBlock:^MImportWebServerResponse *(MImportWebServerRequest* request) {
		
		[[MImportServer shared] resetTimeOutCheck];
		
		NSDictionary* piDictRet = [NSDictionary dictionary];
		NSURL* url = request.URL;
		NSDictionary* cachedUrls = [[NSDictionary alloc] initWithContentsOfFile:@MIMPORT_CACHE_URL]?:@{};
		if(NSString * urlFromMD5St = cachedUrls[[[url lastPathComponent] stringByDeletingPathExtension]]) {
			if(NSURL* urlFromMD5 = [NSURL URLWithString:urlFromMD5St]) {
				if([urlFromMD5 isFileURL]) {
					NSString*filePath = [urlFromMD5 path];
					AudioFileID fileID = nil;
					AudioFileOpenURL((__bridge CFURLRef)[NSURL fileURLWithPath:filePath], kAudioFileReadPermission, 0, &fileID);
					if(fileID) {
						CFDictionaryRef piDict = nil;
						UInt32 piDataSize   = sizeof(piDict);  
						AudioFileGetProperty( fileID, kAudioFilePropertyInfoDictionary, &piDataSize, &piDict);
						AudioFileClose(fileID);
						if(piDict) {
							piDictRet = (__bridge NSDictionary*)piDict;
						}
					}
					NSMutableDictionary* mutDic = [piDictRet mutableCopy];
					mutDic[@"isFileZip"] = (isFileZipAtPath(filePath)>0)?@YES:@NO;
					piDictRet = [mutDic copy];
				}
			}
		}
		return [objc_getClass("MImportWebServerDataResponse") responseWithJSONObject:piDictRet];
	}];
	[_webServer addDefaultHandlerForMethod:@"FILEMAN" requestClass:objc_getClass("MImportWebServerDataRequest") processBlock:^MImportWebServerResponse *(MImportWebServerRequest* request) {
		
		[[MImportServer shared] resetTimeOutCheck];
		
		BOOL returnResp = NO;
		NSString* errorInfo = [NSString string];
		
		int operationType = 0;
		NSString* path1 = nil;
		NSString* path2 = nil;
		NSString* pathDest = [NSString string];
		
		if(NSData* bodyData = ((MImportWebServerDataRequest*)request).data) {
			NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:bodyData];
			if(unarchiver) {
				operationType = [[unarchiver decodeObjectForKey:@"operationType"]?:@(0) intValue];
				path1 = [unarchiver decodeObjectForKey:@"path1"];
				path2 = [unarchiver decodeObjectForKey:@"path2"];
			}
		}
		
		if(operationType == fileOperationDelete) {
			NSError* error = nil;
			returnResp = [[NSFileManager defaultManager] removeItemAtPath:path1 error:&error];
			if(error != nil) {
				errorInfo = [error description];
			}
		} else if(operationType == fileOperationMove) {
			NSError* error = nil;
			returnResp = [[NSFileManager defaultManager] moveItemAtPath:path1 toPath:path2 error:&error];
			if(error != nil) {
				errorInfo = [error description];
			}
		} else if(operationType == fileOperationExtract) {
			int typeFileZip = isFileZipAtPath(path1);
			pathDest = [[path1 stringByDeletingPathExtension] copy];
			int countPath = 0;
			while(path1 && [[NSFileManager defaultManager] fileExistsAtPath:pathDest]) {
				countPath++;
				pathDest = [[path1 stringByDeletingPathExtension] stringByAppendingFormat:@" (%d)", countPath];
			}
			system([NSString stringWithFormat:@"mkdir -p \"%@\"", pathDest].UTF8String);
			int respCmd = system([NSString stringWithFormat:@"cd \"%@\";%@ \"%@\"", pathDest, typeFileZip==1?@"unzip -q":@"unrar x -o+ -ow -tsmca", path1].UTF8String);
			returnResp = !respCmd;
		} else if(operationType == fileOperationCopy) {
			NSError* error = nil;
			returnResp = [[NSFileManager defaultManager] copyItemAtPath:path1 toPath:path2 error:&error];
			if(error != nil) {
				errorInfo = [error description];
			}
		}
		
		NSLog(@"operationType: %d \n returnResp: %@ \n path1: %@ \n path2: %@ \n errorInfo: %@", operationType, @(returnResp), path1, path2, errorInfo);
		
		return [objc_getClass("MImportWebServerDataResponse") responseWithJSONObject:@{@"result":@(returnResp), @"error":errorInfo, @"pathDest": pathDest,}];
	}];
}
%new
- (void)mimportChecker
{
	@autoreleasepool {
		if(access(mimport_running, F_OK) == 0) {
			if(!_webServer) {
				[self mimportAllocServer];
			}
			if(_webServer != nil && !_webServer.running) {
				[_webServer startWithPort:PORT_SERVER bonjourName:nil];
			}			
		} else {
			if(_webServer != nil && _webServer.running) {
				[_webServer stop];
			}
		}
	}
}
%end





__attribute__((constructor)) static void initialize_mimportCenter()
{
	disableServerAndCleanCache(NO);
}


