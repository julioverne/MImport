#import "MImportSB.h"

#define NSLog(...)

#import "../libMImportWebServer/MImportWebServer.h"
#import "../libMImportWebServer/MImportWebServerFileResponse.h"
#import "../libMImportWebServer/MImportWebServerDataRequest.h"
#import "../libMImportWebServer/MImportWebServerDataResponse.h"
#import "../libMImportWebServer/MImportWebUploader.h"

#import "../MImportServerDefines.h"

#import "id3/id3v2lib.h"

static __strong MImportWebServer* _webServer;
static __strong MImportWebUploader* _webServerUploader;

const char* mimport_running = "/private/var/mobile/Media/mimport_running";
const char* mimport_running_uploader = "/private/var/mobile/Media/mimport_running_uploader";

#define MIMPORT_CACHE_URL "/private/var/mobile/Media/mImportCache.plist"

static void disableServerAndCleanCache(BOOL cleanCache)
{
	unlink(mimport_running);
	unlink(mimport_running_uploader);
	if(cleanCache) {
		system([NSString stringWithFormat:@"rm -rf %s", MIMPORT_CACHE_URL].UTF8String);
	}
}

static NSString* encodeBase64WithData(NSData* theData)
{
	@autoreleasepool {
		const uint8_t* input = (const uint8_t*)[theData bytes];
		NSInteger length = [theData length];
		static char table[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";
		NSMutableData* data = [NSMutableData dataWithLength:((length + 2) / 3) * 4];
		uint8_t* output = (uint8_t*)data.mutableBytes;
		NSInteger i;
		for (i=0; i < length; i += 3) {
			NSInteger value = 0;
			NSInteger j;
			for (j = i; j < (i + 3); j++) {
				value <<= 8;
				if (j < length) {
					value |= (0xFF & input[j]);
				}
			}
			NSInteger theIndex = (i / 3) * 4;
			output[theIndex + 0] =			  table[(value >> 18) & 0x3F];
			output[theIndex + 1] =			  table[(value >> 12) & 0x3F];
			output[theIndex + 2] = (i + 1) < length ? table[(value >> 6)  & 0x3F] : '=';
			output[theIndex + 3] = (i + 2) < length ? table[(value >> 0)  & 0x3F] : '=';
		}
		return [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
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

@interface MImportServer : NSObject <MImportWebUploaderDelegate>
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

- (void)webUploader:(MImportWebUploader*)uploader didUploadFileAtPath:(NSString*)path
{
	NSString* base64StringURL = nil;
	NSURL* url = [NSURL fileURLWithPath:path];
	if(url && [(id)url isKindOfClass:[NSURL class]]) {
		base64StringURL = encodeBase64WithData([[(NSURL*)url absoluteString] dataUsingEncoding:NSUTF8StringEncoding]);
		base64StringURL = [base64StringURL stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
		base64StringURL = [base64StringURL stringByReplacingOccurrencesOfString:@"+" withString:@"-"];
		base64StringURL = [base64StringURL stringByReplacingOccurrencesOfString:@"=" withString:@"."];
		if(base64StringURL) {
			[[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"music:///mimport?pathBase=%@", base64StringURL]]];
		}
	}
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
	//dlopen("/usr/lib/libMImportWebServer.dylib", RTLD_LAZY | RTLD_GLOBAL);
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
					//NSLog(@"*** REDIRECT REQUEST TO: %@", urlFromMD5);
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
					mutDic[@"fileSize"] = @([[[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:NULL]?:@{} fileSize]);
					piDictRet = [mutDic copy];
				}
			}
		}
		return [objc_getClass("MImportWebServerDataResponse") responseWithJSONObject:piDictRet];
	}];
	
	[_webServer addDefaultHandlerForMethod:@"WID3" requestClass:objc_getClass("MImportWebServerDataRequest") processBlock:^MImportWebServerResponse *(MImportWebServerRequest* request) {
		
		[[MImportServer shared] resetTimeOutCheck];
		
		BOOL status = NO;		
		@try {
			@autoreleasepool {
				NSString* filePath = nil;
				
				NSString* title = nil;
				NSString* artist = nil;
				NSString* album = nil;
				
				NSString* genre = nil;
				NSString* composer = nil;
				NSNumber* trackNumber = nil;
				NSNumber* year = nil;
				
				NSData* artwork = nil;
				
				if(NSData* bodyData = ((MImportWebServerDataRequest*)request).data) {
					NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:bodyData];
					if(unarchiver) {
						filePath = [unarchiver decodeObjectForKey:@"path"];
						title = [unarchiver decodeObjectForKey:@"title"];
						artist = [unarchiver decodeObjectForKey:@"artist"];
						album = [unarchiver decodeObjectForKey:@"album"];
						artwork = [unarchiver decodeObjectForKey:@"artwork"];
						genre = [unarchiver decodeObjectForKey:@"genre"];
						composer = [unarchiver decodeObjectForKey:@"composer"];
						trackNumber = [unarchiver decodeObjectForKey:@"trackNumber"];
						year = [unarchiver decodeObjectForKey:@"year"];
					}
				}
				
				NSMutableData* filePathData = [[filePath dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
				[filePathData increaseLengthBy:1];
				const char* filePathC = (const char *)filePathData.bytes;
				
				ID3v2_tag* tag = load_tag(filePathC);
				if(tag == NULL) {
					tag = new_tag();
				}
				
				if(title) {
					NSMutableData *sanitizedData = [[title dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
					[sanitizedData increaseLengthBy:1];
					tag_set_title((char*)((NSData*)sanitizedData).bytes, 3, tag);
				}
				if(artist) {
					NSMutableData *sanitizedData = [[artist dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
					[sanitizedData increaseLengthBy:1];
					tag_set_artist((char*)((NSData*)sanitizedData).bytes, 3, tag);
				}
				if(album) {
					NSMutableData *sanitizedData = [[album dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
					[sanitizedData increaseLengthBy:1];
					tag_set_album((char*)((NSData*)sanitizedData).bytes, 3, tag);
				}
				
				if(genre) {
					NSMutableData *sanitizedData = [[genre dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
					[sanitizedData increaseLengthBy:1];
					tag_set_genre((char*)((NSData*)sanitizedData).bytes, 3, tag);
				}
				if(composer) {
					NSMutableData *sanitizedData = [[composer dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
					[sanitizedData increaseLengthBy:1];
					tag_set_composer((char*)((NSData*)sanitizedData).bytes, 3, tag);
				}
				if(trackNumber) {
					NSString* trackNumberSt = [trackNumber stringValue];
					NSMutableData *sanitizedData = [[trackNumberSt dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
					[sanitizedData increaseLengthBy:1];
					tag_set_track((char*)((NSData*)sanitizedData).bytes, 3, tag);
				}
				if(year) {
					NSString* yearSt = [year stringValue];
					NSMutableData *sanitizedData = [[yearSt dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
					[sanitizedData increaseLengthBy:1];
					tag_set_year((char*)((NSData*)sanitizedData).bytes, 3, tag);
				}
				
				if(artwork) {
					tag_set_album_cover_from_bytes((char*)artwork.bytes, (char *)JPG_MIME_TYPE, artwork.length, tag);
				}
				
				set_tag(filePathC, tag);
				
				status = YES;
			}
		}@catch(NSException*e){
			status = NO;
		}
		
		return [objc_getClass("MImportWebServerDataResponse") responseWithJSONObject:@{@"result": @(status),}];
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
		
		//NSLog(@"operationType: %d \n returnResp: %@ \n path1: %@ \n path2: %@ \n errorInfo: %@", operationType, @(returnResp), path1, path2, errorInfo);
		
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
		if(access(mimport_running_uploader, F_OK) == 0) {
			if(!_webServerUploader) {
				_webServerUploader = [[objc_getClass("MImportWebUploader") alloc] initWithUploadDirectory:@"//var/mobile/"];
				_webServerUploader.delegate = [MImportServer shared];
				_webServerUploader.allowHiddenItems = YES;
			}
			if(_webServerUploader != nil && !_webServerUploader.running) {
				[_webServerUploader startWithPort:PORT_SERVER_SHARE bonjourName:nil];
			}			
		} else {
			if(_webServerUploader != nil && _webServerUploader.running) {
				[_webServerUploader stop];
			}
		}		
	}
}
%end





__attribute__((constructor)) static void initialize_mimportCenter()
{
	disableServerAndCleanCache(NO);
}


