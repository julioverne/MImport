#import <AudioToolbox/AudioToolbox.h>

#import "MImportCenter.h"

#import "GCDWebServer/GCDWebServer.h"
#import "GCDWebServer/GCDWebServerFileResponse.h"
#import "GCDWebServer/GCDWebServerDataResponse.h"

#define PORT_SERVER 7565
#define kMaxIdleTimeSeconds 1

__strong GCDWebServer* _webServer;
__strong NSTimer *timerCheckMImport;

const char* mimport_running = "/private/var/mobile/Media/mimport_running";

@interface SpringBoard : NSObject
- (void)mimportAllocServer;
@end

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application
{
    %orig;
	
	unlink(mimport_running);
	if(!_webServer) {
		[self mimportAllocServer];
	}
	if(!timerCheckMImport) {
		timerCheckMImport = [NSTimer scheduledTimerWithTimeInterval:kMaxIdleTimeSeconds target:self selector:@selector(mimportChecker) userInfo:nil repeats:YES];
	}
}
%new
- (void)mimportAllocServer
{
	if(_webServer) {
		return;
	}
	_webServer = [[GCDWebServer alloc] init];
	[_webServer addDefaultHandlerForMethod:@"GET" requestClass:[GCDWebServerRequest class] processBlock:^GCDWebServerResponse *(GCDWebServerRequest* request) {
		return [GCDWebServerFileResponse responseWithFile:[[request.URL path] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] byteRange:request.byteRange];
	}];
	[_webServer addDefaultHandlerForMethod:@"POST" requestClass:[GCDWebServerRequest class] processBlock:^GCDWebServerResponse *(GCDWebServerRequest* request) {
		NSString* filePath = [[request.URL path] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		AudioFileID fileID = nil;
		AudioFileOpenURL((__bridge CFURLRef)[NSURL fileURLWithPath:filePath], kAudioFileReadPermission, 0, &fileID);
		CFDictionaryRef piDict = nil;
		UInt32 piDataSize   = sizeof(piDict);  
		AudioFileGetProperty( fileID, kAudioFilePropertyInfoDictionary, &piDataSize, &piDict);
		if(!piDict) {
			piDict = (__bridge CFDictionaryRef)[NSMutableDictionary dictionary];
		}
		AudioFileClose(fileID);
		return [GCDWebServerDataResponse responseWithJSONObject:(__bridge NSDictionary *)piDict];
	}];
}
%new
- (void)mimportChecker
{
	@autoreleasepool {
		if(!_webServer) {
			[self mimportAllocServer];
		}
		if (access(mimport_running, F_OK) == 0) {
			if(!_webServer.running) {
				[_webServer startWithPort:PORT_SERVER bonjourName:nil];
			}			
		} else {
			if(_webServer.running) {
				[_webServer stop];
			}
		}
	}
}
%end



static void lockScreenState(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	@autoreleasepool {
		unlink(mimport_running);
	}
}


__attribute__((constructor)) static void initialize_mimportCenter()
{
	@autoreleasepool {
		CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, lockScreenState, CFSTR("com.apple.springboard.lockstate"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
		unlink(mimport_running);
	}
}


