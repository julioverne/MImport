#import <AudioToolbox/AudioToolbox.h>

#import "MImportSB.h"

#import "../libMImportWebServer/MImportWebServer.h"
#import "../libMImportWebServer/MImportWebServerFileResponse.h"
#import "../libMImportWebServer/MImportWebServerDataResponse.h"

#define PORT_SERVER 4194
#define kMaxIdleTimeSeconds 2
#define SERVER_TIMEOUT_SECONDS 3600

static __strong MImportWebServer* _webServer;

const char* mimport_running = "/private/var/mobile/Media/mimport_running";

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
	unlink(mimport_running);
}
@end

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application
{
    %orig;
	unlink(mimport_running);
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
		NSDictionary* cachedUrls = [[NSDictionary alloc] initWithContentsOfFile:@"/private/var/mobile/Media/mImportCache.plist"]?:@{};
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
		
		CFDictionaryRef piDict = nil;
		NSURL* url = request.URL;
		NSDictionary* cachedUrls = [[NSDictionary alloc] initWithContentsOfFile:@"/private/var/mobile/Media/mImportCache.plist"]?:@{};
		if(NSString * urlFromMD5St = cachedUrls[[[url lastPathComponent] stringByDeletingPathExtension]]) {
			if(NSURL* urlFromMD5 = [NSURL URLWithString:urlFromMD5St]) {
				if([urlFromMD5 isFileURL]) {
					NSString*filePath = [urlFromMD5 path];
					AudioFileID fileID = nil;
					AudioFileOpenURL((__bridge CFURLRef)[NSURL fileURLWithPath:filePath], kAudioFileReadPermission, 0, &fileID);
					if(fileID) {
						UInt32 piDataSize   = sizeof(piDict);  
						AudioFileGetProperty( fileID, kAudioFilePropertyInfoDictionary, &piDataSize, &piDict);
						AudioFileClose(fileID);
					}
				}
			}
		}
		if(!piDict) {
			piDict = (__bridge CFDictionaryRef)[NSDictionary dictionary];
		}
		return [objc_getClass("MImportWebServerDataResponse") responseWithJSONObject:(__bridge NSDictionary*)piDict];
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
	unlink(mimport_running);
}


