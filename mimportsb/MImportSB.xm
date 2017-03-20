#import <AudioToolbox/AudioToolbox.h>

#import "MImportSB.h"

#import "../libMImportWebServer/MImportWebServer.h"
#import "../libMImportWebServer/MImportWebServerFileResponse.h"
#import "../libMImportWebServer/MImportWebServerDataResponse.h"

#define PORT_SERVER 4194
#define kMaxIdleTimeSeconds 1

__strong MImportWebServer* _webServer;
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
	dlopen("/usr/lib/libMImportWebServer.dylib", RTLD_LAZY | RTLD_GLOBAL);
	_webServer = [[objc_getClass("MImportWebServer") alloc] init];
	[_webServer addDefaultHandlerForMethod:@"GET" requestClass:objc_getClass("MImportWebServerRequest") processBlock:^MImportWebServerResponse *(MImportWebServerRequest* request) {
		return [objc_getClass("MImportWebServerFileResponse") responseWithFile:[[request.URL path] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] byteRange:request.byteRange];
	}];
	[_webServer addDefaultHandlerForMethod:@"POST" requestClass:objc_getClass("MImportWebServerRequest") processBlock:^MImportWebServerResponse *(MImportWebServerRequest* request) {
		NSString* filePath = [[request.URL path] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		AudioFileID fileID = nil;
		CFDictionaryRef piDict = nil;
		AudioFileOpenURL((__bridge CFURLRef)[NSURL fileURLWithPath:filePath], kAudioFileReadPermission, 0, &fileID);
		if(fileID) {
			UInt32 piDataSize   = sizeof(piDict);  
			AudioFileGetProperty( fileID, kAudioFilePropertyInfoDictionary, &piDataSize, &piDict);
			AudioFileClose(fileID);
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


