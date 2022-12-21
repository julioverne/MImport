#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <sys/types.h>
#import <sys/stat.h>
#import <fcntl.h>
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import <CoreFoundation/CFUserNotification.h>
#import <CommonCrypto/CommonCrypto.h>
#import <substrate.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import "MImport.h"

#define NSLog(...)

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

const char* mimport_running = "/private/var/mobile/Media/mimport_running";
const char* mimport_running_uploader = "/private/var/mobile/Media/mimport_running_uploader";

static __strong NSString* const kPathWork = @"/";// @"/private/var/mobile/Media/";
static __strong NSString* const kExt = @"fileExtension";
static __strong NSString* const kIsFileZip = @"isFileZip";
static __strong NSString* const kFileSize = @"fileSize";
static __strong NSString* const kSearchTitle = @"searchTitle";
static __strong NSString* const kTitle = @"title";
static __strong NSString* const kAlbum = @"album";
static __strong NSString* const kArtist = @"artist";
static __strong NSString* const kGenre = @"genre";
static __strong NSString* const kComposer = @"composer";
static __strong NSString* const kLyrics = @"lyrics";
static __strong NSString* const kYear = @"year";
static __strong NSString* const kTrackNumber = @"trackNumber";
static __strong NSString* const kTrackCount = @"trackCount";
static __strong NSString* const kExplicit = @"explicit";
static __strong NSString* const kArtwork = @"artwork";
static __strong NSString* const kKindType = @"kind";
static __strong NSString* const kDuration = @"approximate duration in seconds";
static __strong NSString* const kUrlServer = [NSString stringWithFormat:@"http://%@:%i/", @"127.0.0.1", PORT_SERVER];
static __strong NSString* const kMImportCacheServer = @"/private/var/mobile/Media/mImportCache.plist";


@interface actionShetModel : NSObject
@property (strong) NSString* context;
@property (assign) int cancelButtonIndex;
@property (assign) int tag;
@property (strong) NSString* buttonName;
- (NSString *)buttonTitleAtIndex:(int)arg1;
@end

@implementation actionShetModel
@synthesize context, cancelButtonIndex, tag, buttonName;
- (NSString *)buttonTitleAtIndex:(int)arg1
{
	return self.buttonName;
}
@end

static UIViewController *_topMostController(UIViewController *cont)
{
    UIViewController *topController = cont;
    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }
    if ([topController isKindOfClass:[UINavigationController class]]) {
        UIViewController *visible = ((UINavigationController *)topController).visibleViewController;
        if (visible) {
            topController = visible;
        }
    }
    return (topController != cont ? topController : nil);
}
static UIViewController *topMostController()
{
    UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;
    UIViewController *next = nil;
    while ((next = _topMostController(topController)) != nil) {
        topController = next;
    }
    return topController;
}

static __strong UIImage* kIconMimport;
static UIImage* kIconMimportGet()
{
	if(!kIconMimport) {
		kIconMimport = [[UIImage alloc] initWithContentsOfFile:[[NSBundle bundleWithPath:@"/Library/PreferenceBundles/MImport.bundle"]?:[NSBundle mainBundle] pathForResource:@"icon" ofType:@"png"]];
		if(kIconMimport && [kIconMimport respondsToSelector:@selector(imageWithRenderingMode:)]) {
			kIconMimport = [[kIconMimport imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] copy];
		}
	}
	return kIconMimport;
}

static __strong UIImage* kImageDir;
static UIImage* kImageDirGet()
{
	if(!kImageDir) {
		kImageDir = [[UIImage alloc] initWithContentsOfFile:[[NSBundle bundleWithPath:@"/Library/PreferenceBundles/MImport.bundle"]?:[NSBundle mainBundle] pathForResource:@"dir" ofType:@"png"]];
		if(kImageDir && [kImageDir respondsToSelector:@selector(imageWithRenderingMode:)]) {
			kImageDir = [[kImageDir imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] copy];
		}
	}
	return kImageDir;
}

static __strong NSURL* receivedURLMImport;
static BOOL receivedURLMImport_autoFetchTags;

static BOOL needShowAgainMImportURL;

static BOOL showAllFileTypes;

/*%hook SSDownloadMetadata
- (id)initWithDictionary:(id)arg1
{
	id orig = %orig;
	if(arg1) {
		[(NSDictionary*)arg1 writeToFile:@"//private/var/mobile/Media/SSDownloadMetadata_dic_received.plist" atomically:YES];
	}	
	return orig;
}
%end*/

static NSString* getHeaderName()
{
	static __strong NSString* headerNameMimport;
	if(!headerNameMimport) {
		NSDateComponents *components = [[NSCalendar currentCalendar] components:NSCalendarUnitYear fromDate:[NSDate date]];
		headerNameMimport = [NSString stringWithFormat:@"\n\nMImport © %d julioverne\n\n\n\n\n\n\n", (int)[components year]];
	}
	return headerNameMimport;
}

static void toogleShowAllFileTypes()
{
	showAllFileTypes = !showAllFileTypes;
	[[NSUserDefaults standardUserDefaults] setObject:@(showAllFileTypes) forKey:@"MImport-AnyFile"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

static NSString * formatFileSizeFromBytes(long long fileSize)
{
    return [NSByteCountFormatter stringFromByteCount:fileSize countStyle:NSByteCountFormatterCountStyleFile];
}

static BOOL isStartingServerInProgress;
static void startServer()
{
	while(isStartingServerInProgress) {
		sleep(1/4);
	}
	if(!isStartingServerInProgress && access(mimport_running, F_OK) != 0) {
		isStartingServerInProgress = YES;
		__block UIProgressHUD* hud = [[UIProgressHUD alloc] init];
		UIWindow* appWindow = [[UIApplication sharedApplication] keyWindow];
		if(appWindow) {
			dispatch_async(dispatch_get_main_queue(), ^(void) {
				appWindow.userInteractionEnabled = NO;
				[hud setText:@"Starting MImport..."];
				[hud showInView:appWindow];
			});
		}
		close(open(mimport_running, O_CREAT));
		//usleep(2400000);
		while(true) {
			@autoreleasepool {
				sleep(1/3);
				NSError *error = nil;
				NSMutableURLRequest *Request = [[NSMutableURLRequest alloc]	initWithURL:[NSURL URLWithString:kUrlServer] cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:4];
				__autoreleasing NSData *receivedData = [NSURLConnection sendSynchronousRequest:Request returningResponse:nil error:&error];
				if(!error && receivedData) {
					break;
				}
			}
		}
		if(appWindow) {
			dispatch_async(dispatch_get_main_queue(), ^(void) {
				appWindow.userInteractionEnabled = YES;
				[hud hide];
			});
		}
		isStartingServerInProgress = NO;
	}
}


static NSURL* fixURLRemoteOrLocalWithPath(NSString* inPath)
{
	NSString* inPathRet = inPath;
	if([inPathRet hasPrefix:@"file:"]) {
		if(NSString* try1 = [[NSURL URLWithString:inPathRet] path]) {
			inPathRet = try1;
		}
		if([inPathRet hasPrefix:@"file:"]) {
			inPathRet = [inPathRet substringFromIndex:5];
		}
	}
	while([inPathRet hasPrefix:@"//"]) {
		inPathRet = [inPathRet substringFromIndex:1];
	}
	NSURL* retURL = [inPathRet hasPrefix:@"/"]?[NSURL fileURLWithPath:inPathRet]:[NSURL URLWithString:inPathRet];
	//NSLog(@"*** fixURLRemoteOrLocalWithPath:\n inPath: %@ \n inPathRet: %@ \n retURL: %@", inPath, inPathRet, retURL);
	return retURL;
}

@interface UITabBarItem (priv)
- (void)_setInternalTitle:(id)arg1;
@end
@interface MImportTapMenu : NSObject <UITabBarDelegate> {
	NSString *_pathFav;
}
@property(nonatomic,retain) NSString *pathFav;
+ (id)sharedInstance;
- (void)applyTabBarNavController:(UINavigationController*)navc;
- (void)_deviceOrientationDidChange;
@end

@interface UIWindow (CD)
@property(nonatomic, readonly) UIEdgeInsets safeAreaInsets;
@end

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

static NSData * base64DataFromString(NSString * string)
{
	@autoreleasepool {
		unsigned long ixtext, lentext;
		unsigned char ch, inbuf[4], outbuf[3];
		short i, ixinbuf;
		Boolean flignore, flendtext = false;
		const unsigned char *tempcstring;
		NSMutableData *theData;
		if(string == nil) {
			return [NSData data];
		}
		ixtext = 0;
		tempcstring = (const unsigned char *)[string UTF8String];
		lentext = [string length];
		theData = [NSMutableData dataWithCapacity: lentext];
		ixinbuf = 0;
		while(true) {
			if(ixtext >= lentext) {
				break;
			}
			ch = tempcstring [ixtext++];
			flignore = false;
			if((ch >= 'A') && (ch <= 'Z')) {
				ch = ch - 'A';
			} else if((ch >= 'a') && (ch <= 'z')) {
				ch = ch - 'a' + 26;
			} else if((ch >= '0') && (ch <= '9')) {
				ch = ch - '0' + 52;
			} else if(ch == '+') {
				ch = 62;
			} else if(ch == '=') {
				flendtext = true;
			} else if(ch == '/') {
				ch = 63;
			} else {
				flignore = true; 
			}
			if(!flignore) {
				short ctcharsinbuf = 3;
				Boolean flbreak = false;
				if(flendtext) {
					if(ixinbuf == 0) {
						break;
					}
					if((ixinbuf == 1) || (ixinbuf == 2)) {
						ctcharsinbuf = 1;
					} else {
						ctcharsinbuf = 2;
					}
					ixinbuf = 3;
					flbreak = true;
				}
				inbuf [ixinbuf++] = ch;
				if(ixinbuf == 4) {
					ixinbuf = 0;
					outbuf[0] = (inbuf[0] << 2) | ((inbuf[1] & 0x30) >> 4);
					outbuf[1] = ((inbuf[1] & 0x0F) << 4) | ((inbuf[2] & 0x3C) >> 2);
					outbuf[2] = ((inbuf[2] & 0x03) << 6) | (inbuf[3] & 0x3F);
					for (i = 0; i < ctcharsinbuf; i++) {
						[theData appendBytes: &outbuf[i] length: 1];
					}
				}
				if(flbreak) {
					break;
				}
			}
		}
		return theData;
	}
}

static NSString* hmacSHA1BinBase64(NSString* data, NSString* key) 
{
	@autoreleasepool {
		const char *cKey  = [key cStringUsingEncoding:NSASCIIStringEncoding];
		const char *cData = [data cStringUsingEncoding:NSASCIIStringEncoding];
		unsigned char cHMAC[CC_SHA1_DIGEST_LENGTH];
		CCHmac(kCCHmacAlgSHA1, cKey, strlen(cKey), cData, strlen(cData), cHMAC);
		NSData *HMAC = [[NSData alloc] initWithBytes:cHMAC length:sizeof(cHMAC)];
		NSString *hash = encodeBase64WithData(HMAC);
		return hash;
	}
}

static NSString* md5String(NSString* stringSt) 
{
	@autoreleasepool {
		const char* str = [stringSt UTF8String];
		unsigned char result[CC_MD5_DIGEST_LENGTH];
		CC_MD5(str, strlen(str), result);
		NSMutableString *ret = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH*2];
		for(int i = 0; i<CC_MD5_DIGEST_LENGTH; i++) {
			[ret appendFormat:@"%02x",result[i]];
		}
		return ret;
	}
}

static NSString* urlEncodeUsingEncoding(NSString* encoding)
{
	static __strong NSString* kCodes = @"!*'\"();:@&=+$,?%#[] ";
	return (__bridge NSString*)CFURLCreateStringByAddingPercentEscapes(NULL, (__bridge CFStringRef)encoding, NULL, (__bridge CFStringRef)kCodes, CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));
}

static NSDictionary* getMusicInfo(NSDictionary* item)
{
	NSMutableDictionary* retInfo = [NSMutableDictionary mutableCopy];
	if(item) {
		@try {
			NSString *artist, *album, *album_artist, *track, *duration;
			artist = [[item objectForKey:kArtist]?:[NSString string] copy];
			album = [[item objectForKey:kAlbum]?:[NSString string] copy];
			album_artist = [[item objectForKey:@"albumArtist"]?:[NSString string] copy];
			track = [[item objectForKey:kTitle]?:[NSString string] copy];
			duration = [[[item objectForKey:kDuration]?:@(0) stringValue]?:[NSString string] copy];
			NSString* token = @"1806241a800384d1588f4bde531da16e19ac746268a4999ebae016";
			NSString* sigFormat = @"&signature=%@&signature_protocol=sha1";
			NSString* urlFormat = @"https://apic.musixmatch.com/ws/1.1/macro.subtitles.get?app_id=mac-ios-v2.0&usertoken=%@&q_duration=%@&tags=playing&q_album_artist=%@&q_track=%@&q_album=%@&page_size=1&subtitle_format=mxm&f_subtitle_length_max_deviation=1&user_language=pt&f_tracking_url=html&f_subtitle_length=%@&track_fields_set=ios_track_list&q_artist=%@&format=json";
			NSString* prepareString = [NSString stringWithFormat:urlFormat, token, duration, urlEncodeUsingEncoding(album_artist), urlEncodeUsingEncoding(track), urlEncodeUsingEncoding(album), duration, urlEncodeUsingEncoding(artist)];
			__autoreleasing NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
			[formatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
			[formatter setDateFormat:@"yyyMMdd"];
			NSString* dateToday = [NSString stringWithFormat:@"%d", [[formatter stringFromDate:[NSDate date]] intValue]];
			NSURL* UrlString = [NSURL URLWithString:[prepareString stringByAppendingString:[NSString stringWithFormat:sigFormat, urlEncodeUsingEncoding(hmacSHA1BinBase64([prepareString stringByAppendingString:dateToday], @"secretsuper"))]]];
			if(UrlString != nil) {
				NSError *error = nil;
				NSHTTPURLResponse *responseCode = nil;
				NSMutableURLRequest *Request = [[NSMutableURLRequest alloc]	initWithURL:UrlString cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:30.0];
				[Request setHTTPMethod:@"GET"];
				[Request setValue:@"default; AWSELB=unknown" forHTTPHeaderField:@"Cookie"];
				[Request setValue:@"default" forHTTPHeaderField:@"x-mxm-endpoint"];
				[Request setValue:@"Musixmatch/6.0.1 (iPhone; iOS 9.2.1; Scale/2.00)" forHTTPHeaderField:@"User-Agent"];
				__autoreleasing NSData *receivedData = [NSURLConnection sendSynchronousRequest:Request returningResponse:&responseCode error:&error];
				if(receivedData && !error) {
					NSDictionary *JSON = [NSJSONSerialization JSONObjectWithData:receivedData?:[NSData data] options:NSJSONReadingMutableContainers error:nil];
					@try {
						NSDictionary* trackInfo = JSON[@"message"][@"body"][@"macro_calls"][@"matcher.track.get"][@"message"][@"body"][@"track"];
						retInfo = [trackInfo mutableCopy];
					} @catch (NSException * e) {
						
					}
					@try {
						NSDictionary* lyricsInfo = JSON[@"message"][@"body"][@"macro_calls"][@"track.lyrics.get"][@"message"][@"body"][@"lyrics"];
						if(lyricsInfo[@"lyrics_body"] != nil) {
							retInfo[@"lyrics"] = lyricsInfo[@"lyrics_body"];
						}
					} @catch (NSException * e) {
						
					}
				} else if (error) {
					dispatch_async(dispatch_get_main_queue(), ^(void) {
						NSString* titleSt = @"MImport";
						NSString* messageSt = [error description];
						NSString* okSt = @"OK";
						
						if(%c(UIAlertController) != nil) {
							UIAlertController* alert = [%c(UIAlertController) alertControllerWithTitle:titleSt message:messageSt preferredStyle:UIAlertControllerStyleAlert];
							UIAlertAction* defaultAction = [%c(UIAlertAction) actionWithTitle:okSt style:UIAlertActionStyleDefault handler:nil];
							[alert addAction:defaultAction];
							[topMostController() presentViewController:alert animated:YES completion:nil];
						} else {
							UIAlertView *alert = [[%c(UIAlertView) alloc] initWithTitle:titleSt message:messageSt delegate:nil cancelButtonTitle:okSt otherButtonTitles:nil];
							[alert show];
						}
					});
				}
			}
		} @catch (NSException * e) {
		}
	}
	return retInfo;
}

static NSURL* fixedMImportURLCachedWithURL(NSURL* mediaURL, NSString* preferExt)
{
	if(mediaURL) {
		@autoreleasepool {
			startServer();
			NSMutableDictionary* cachedUrls = [[[NSDictionary alloc] initWithContentsOfFile:kMImportCacheServer]?:@{} mutableCopy];
			NSString* mediaURLSt = [mediaURL absoluteString];
			if([mediaURLSt rangeOfString:kUrlServer].location != NSNotFound) {
				return mediaURL;
			}
			NSString* md5StringURLSt = md5String(mediaURLSt);
			cachedUrls[md5StringURLSt] = mediaURLSt;
			[cachedUrls writeToFile:kMImportCacheServer atomically:YES];
			NSString* exten = preferExt?:[mediaURLSt pathExtension];
			return [NSURL URLWithString:[NSString stringWithFormat:@"%@%@.%@", kUrlServer, md5StringURLSt, [exten&&exten.length>0?exten:@"unknown" lowercaseString]]];
		}
	}
	return nil;
}

static void playFromURLWithViewController(UIViewController* selfNow, NSURL* mediaURL)
{
	@try {
		[[%c(AVAudioSession) sharedInstance] setActive:YES error:nil];
		[[%c(AVAudioSession) sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
		AVPlayer* player = [%c(AVPlayer) playerWithURL:fixedMImportURLCachedWithURL(mediaURL,nil)];
		AVPlayerViewController *playerViewController = [%c(AVPlayerViewController) new];
		playerViewController.player = player;
		[selfNow presentViewController:playerViewController animated:YES completion:^{
			[player play];
		}];
	} @catch (NSException * e) {
	}
}

static BOOL fileOperation(int operationType, NSString* path1, NSString* path2, NSString** pathDest)
{
	BOOL result = NO;
	
	NSMutableData* dataMut = [[NSMutableData alloc] init];
	NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:dataMut];
	[archiver encodeObject:@(operationType) forKey:@"operationType"];
	if(path1) {
		[archiver encodeObject:path1 forKey:@"path1"];
	}
	if(path2) {
		[archiver encodeObject:path2 forKey:@"path2"];
	}
	[archiver finishEncoding];
	
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:kUrlServer]];
	[request setHTTPMethod:@"FILEMAN"];
	[request setTimeoutInterval:3600];
	[request setHTTPBody:dataMut];
	request.cachePolicy = NSURLRequestReloadIgnoringLocalAndRemoteCacheData;
	NSError* error = nil;
	__autoreleasing NSData* data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:&error];
	if(data) {
		NSDictionary *jsonDic = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil]?:@{};
		result = [jsonDic[@"result"]?:@NO boolValue];
		NSString* errorSt = jsonDic[@"error"]?:[NSString string];
		if(pathDest) {
			*pathDest = jsonDic[@"pathDest"];
		}
		if([errorSt length]>0 || !result) {
			dispatch_async(dispatch_get_main_queue(), ^(void) {
				NSString* titleSt = @"MImport";
				NSString* messageSt = ([errorSt length]>0)?errorSt:@"Error";
				NSString* okSt = @"OK";
				
				if(%c(UIAlertController) != nil) {
					UIAlertController* alert = [%c(UIAlertController) alertControllerWithTitle:titleSt message:messageSt preferredStyle:UIAlertControllerStyleAlert];
					UIAlertAction* defaultAction = [%c(UIAlertAction) actionWithTitle:okSt style:UIAlertActionStyleDefault handler:nil];
					[alert addAction:defaultAction];
					[topMostController() presentViewController:alert animated:YES completion:nil];
				} else {
					UIAlertView *alert = [[%c(UIAlertView) alloc] initWithTitle:titleSt message:messageSt delegate:nil cancelButtonTitle:okSt otherButtonTitles:nil];
					[alert show];
				}
			});
		}
	}
	if(error) {
		dispatch_async(dispatch_get_main_queue(), ^(void) {
			NSString* titleSt = @"MImport";
			NSString* messageSt = [error description];
			NSString* okSt = @"OK";
			
			if(%c(UIAlertController) != nil) {
				UIAlertController* alert = [%c(UIAlertController) alertControllerWithTitle:titleSt message:messageSt preferredStyle:UIAlertControllerStyleAlert];
				UIAlertAction* defaultAction = [%c(UIAlertAction) actionWithTitle:okSt style:UIAlertActionStyleDefault handler:nil];
				[alert addAction:defaultAction];
				[topMostController() presentViewController:alert animated:YES completion:nil];
			} else {
				UIAlertView *alert = [[%c(UIAlertView) alloc] initWithTitle:titleSt message:messageSt delegate:nil cancelButtonTitle:okSt otherButtonTitles:nil];
				[alert show];
			}
		});
	}	
	return result;
}

static NSDictionary* fileTagsAtURL(NSURL* fileServerURL)
{
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:fileServerURL];
	[request setHTTPMethod:@"POST"];
	request.cachePolicy = NSURLRequestReloadIgnoringLocalAndRemoteCacheData;
	NSError* error = nil;
	__autoreleasing NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:&error];
	if(error) {
		dispatch_async(dispatch_get_main_queue(), ^(void) {
			NSString* titleSt = @"MImport";
			NSString* messageSt = [error description];
			NSString* okSt = @"OK";
			
			if(%c(UIAlertController) != nil) {
				UIAlertController* alert = [%c(UIAlertController) alertControllerWithTitle:titleSt message:messageSt preferredStyle:UIAlertControllerStyleAlert];
				UIAlertAction* defaultAction = [%c(UIAlertAction) actionWithTitle:okSt style:UIAlertActionStyleDefault handler:nil];
				[alert addAction:defaultAction];
				[topMostController() presentViewController:alert animated:YES completion:nil];
			} else {
				UIAlertView *alert = [[%c(UIAlertView) alloc] initWithTitle:titleSt message:messageSt delegate:nil cancelButtonTitle:okSt otherButtonTitles:nil];
				[alert show];
			}
		});
	}
	return [[NSJSONSerialization JSONObjectWithData:data?:[NSData data] options:kNilOptions error:NULL]?:@{} copy];
}

static void MImport_import(NSURL *mediaURL, NSDictionary *mediaInfo, BOOL fetchTags)
{
	@try {
		startServer();
	@autoreleasepool {
	if(!mediaURL ||(mediaURL&&!([mediaURL absoluteString].length>0))) {
		return;
	}
	if(!mediaInfo) {
		mediaInfo = [NSDictionary dictionary];
	}
	
	NSString *ext = [[[[mediaURL path] lastPathComponent]?:@"" pathExtension]?:@"" lowercaseString];	
	
	__strong NSURL *audioURL = fixedMImportURLCachedWithURL(mediaURL, [mediaInfo objectForKey:kExt]);
	
	NSDictionary* piDict = [NSDictionary dictionary];
	
	if(fetchTags&&[mediaURL isFileURL]) {
		piDict = fileTagsAtURL(audioURL);
	}
	
	//NSLog(@"*** MImport_import() \n Server URL: %@ \n Path: %@ \n piDict: %@", [audioURL absoluteString], mediaURL, piDict);
	
	
	
	NSMutableDictionary* metaDataParse = [NSMutableDictionary dictionary];
	AVAsset *asset;
	if(fetchTags) {
	NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:AVAssetReferenceRestrictionForbidNone], AVURLAssetReferenceRestrictionsKey, nil];
    asset = [AVURLAsset URLAssetWithURL:audioURL options:options];
    for (NSString *format in [asset availableMetadataFormats]) {
        for (AVMetadataItem *item in [asset metadataForFormat:format]) {
            if ([[item commonKey] isEqualToString:kTitle]) {
				metaDataParse[kTitle] = [item value];
            }
            if ([[item commonKey] isEqualToString:kArtist]) {
				metaDataParse[kArtist] = [item value];
            }
            if ([[item commonKey] isEqualToString:@"albumName"]) {
				metaDataParse[@"albumName"] = [item value];
            }
			if ([[item commonKey] isEqualToString:@"copyrights"]) {
				metaDataParse[@"copyright"] = [item value];
            }
            if ([[item commonKey] isEqualToString:kArtwork]) {
                if ([[item value] isKindOfClass:[NSDictionary class]]) {
					metaDataParse[kArtwork] = ((NSDictionary*)[item value])[@"data"];
                } else {
					metaDataParse[kArtwork] = [item value];
                }
			}
        }
	}
	}
	
	NSData* imageData = [mediaInfo objectForKey:kArtwork]?:[metaDataParse objectForKey:kArtwork];
	NSString*artworkPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[[mediaURL path] lastPathComponent]];
	if(ext.length>0) {
		artworkPath = [artworkPath stringByDeletingPathExtension];
	}
	artworkPath = [artworkPath stringByAppendingPathExtension:@"jpeg"];
	
	[[NSFileManager defaultManager] removeItemAtPath:artworkPath error:nil];
	[[NSFileManager defaultManager] removeItemAtPath:[[artworkPath stringByDeletingPathExtension] stringByAppendingPathExtension:@"jpg"] error:nil];
	[[NSFileManager defaultManager] removeItemAtPath:[[artworkPath stringByDeletingPathExtension] stringByAppendingPathExtension:@"png"] error:nil];
	
	
	if(fetchTags) {
		if(!imageData&&[mediaURL isFileURL]) {
			NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:fixedMImportURLCachedWithURL([NSURL fileURLWithPath:[[artworkPath stringByDeletingPathExtension] stringByAppendingPathExtension:@"jpeg"]], nil)];
			request.cachePolicy = NSURLRequestReloadIgnoringLocalAndRemoteCacheData;
			imageData = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
			if(imageData) {
				if([imageData length] == 0) {
					imageData = nil;
				}
			}
			if(!imageData) {
				request = [NSMutableURLRequest requestWithURL:fixedMImportURLCachedWithURL([NSURL fileURLWithPath:[[artworkPath stringByDeletingPathExtension] stringByAppendingPathExtension:@"jpg"]], nil)];
				request.cachePolicy = NSURLRequestReloadIgnoringLocalAndRemoteCacheData;
				imageData = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
			}
			if(imageData) {
				if([imageData length] == 0) {
					imageData = nil;
				}
			}
			if(!imageData) {
				request = [NSMutableURLRequest requestWithURL:fixedMImportURLCachedWithURL([NSURL fileURLWithPath:[[artworkPath stringByDeletingPathExtension] stringByAppendingPathExtension:@"png"]], nil)];
				request.cachePolicy = NSURLRequestReloadIgnoringLocalAndRemoteCacheData;
				imageData = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
			}
			if(imageData) {
				if([imageData length] == 0) {
					imageData = nil;
				}
			}
		}
	}
    if (imageData != nil && imageData.length > 0) {
		UIImage* image = [UIImage imageWithData:imageData];
        [UIImageJPEGRepresentation(image, 1.0) writeToFile:artworkPath atomically:YES];
    }
	
	NSString *title, *album, *artist, *copyright, *genre, *composer, *lyric;
	
	title     = [mediaInfo objectForKey:kTitle]?:[metaDataParse objectForKey:kTitle]?:[piDict objectForKey:kTitle]?:[[[mediaURL path] lastPathComponent] stringByDeletingPathExtension]?:@"Unknown Title";
	album     = [mediaInfo objectForKey:kAlbum]?:[metaDataParse objectForKey:@"albumName"]?:[piDict objectForKey:kAlbum]?:@"Unknown Album";
	artist    = [mediaInfo objectForKey:kArtist]?:[metaDataParse objectForKey:kArtist]?:[piDict objectForKey:kArtist]?:@"Unknown Artist";
	copyright = [metaDataParse objectForKey:@"copyright"]?:[piDict objectForKey:@"copyright"]?:@"\u2117 MImport.";
	genre     = [mediaInfo objectForKey:kGenre]?:[piDict objectForKey:kGenre];
	composer  = [mediaInfo objectForKey:kComposer]?:[piDict objectForKey:kComposer];
	lyric     = [mediaInfo objectForKey:kLyrics];
	
	int durationSecond = 0;
	NSDateComponents *components = [[NSCalendar currentCalendar] components:NSCalendarUnitYear fromDate:[NSDate date]];
	int year = (int)[components year];
	int trackNumber = 1;
	int trackCount = 1;
	int isExplicit = 0;
	
	durationSecond = [[mediaInfo objectForKey:kDuration]?:[piDict objectForKey:kDuration]?:@(0) intValue];
	
	if(durationSecond == 0) {
		if(asset) {
			durationSecond = CMTimeGetSeconds(asset.duration);
		}
	}	
	
	if(id yearID = [piDict objectForKey:kYear]) {
		if(NSString* yearSt = [NSString stringWithFormat:@"%@", yearID]) {
			if([(NSString*)yearSt length] == 4) {
				year = [yearSt intValue]; 
			} else if([(NSString*)yearSt length] > 4) {
				yearSt = [yearSt substringToIndex:4];
				year = [yearSt intValue]; 
			}
		}
	}
	if(id TrackID = [piDict objectForKey:@"track number"]) {
		if([TrackID isKindOfClass:[NSNumber class]]) {
			trackNumber = [TrackID intValue];
		} else if([TrackID isKindOfClass:[NSString class]]) {
			NSArray* itemArr = [TrackID componentsSeparatedByString:@"/"]?:[NSArray array];
			int index = 0;
			for(id sItemNow in itemArr) {
				if(index == 0) {
					trackNumber = [sItemNow intValue];
				} else {
					trackCount = [sItemNow intValue];
				}
				index++;
			}
		}
	}
	
	if(id yearMedia = [mediaInfo objectForKey:kYear]) {
		year = [yearMedia intValue];
	}
	if(id trackNumberMedia = [mediaInfo objectForKey:kTrackNumber]) {
		trackNumber = [trackNumberMedia intValue];
	}
	if(id trackCountMedia = [mediaInfo objectForKey:kTrackCount]) {
		trackCount = [trackCountMedia intValue];
	}
	if(id explicitMedia = [mediaInfo objectForKey:kExplicit]) {
		isExplicit = [explicitMedia intValue];
	}
	
	long long itemGet = (arc4random() % 100000000) + 1;
	int itemID = itemGet;
	
	
	
	NSString* artworkURLString = [fixedMImportURLCachedWithURL([NSURL fileURLWithPath:artworkPath], nil) absoluteString];
	
	
	
	NSString *kindType = kIPIMediaSong;
	if ([ext isEqualToString:@"mp4"] || [ext isEqualToString:@"m4v"] || [ext isEqualToString:@"mov"] || [ext isEqualToString:@"3gp"]) {
		kindType = kIPIMediaMusicVideo;
	} else if ([ext isEqualToString:@"m4r"]) {
		kindType = kIPIMediaRingtone;
	}
	if(id kindMedia = [mediaInfo objectForKey:kKindType]) {
		int kindInt = [kindMedia intValue];
		if(kindInt == 1) {
			kindType = kIPIMediaSong;
		} else if(kindInt == 2) {
			kindType = kIPIMediaMusicVideo;
		} else if(kindInt == 3) {
			kindType = kIPIMediaTVEpisode;
		} else if(kindInt == 4) {
			kindType = kIPIMediaRingtone;
		}
	}
	
	
	NSDictionary* payloadImport = @{
		@"purchaseDate": [NSDate date],
		@"is-purchased-redownload": @YES,
		
		@"URL": [audioURL absoluteString],
		
		@"artworkURL": artworkURLString?:@"",
		
		@"artwork-urls": @{
			@"default": @{
				@"url": artworkURLString?:@"",
			}, 
	        @"image-type": @"download-queue-item",
	    },
		
		@"songId": @(itemID),
		
		@"metadata": @{
			 //@"artistId": @(602767352),
	        @"artistName": artist?:@"",
	         //@"bitRate": @(256),
	        @"compilation": @NO,
	         //@"composerId": @(327699389),
	        @"composerName": composer?:@"",
	        @"copyright": copyright?:@"",
			@"description": copyright?:@"",
			@"longDescription": copyright?:@"",
			
			//@"lyrics": lyric,
			
	         //@"discCount": @(1),
	         //@"discNumber": @(1),
	        @"drmVersionNumber": @(0),
	        @"duration": @(durationSecond * 1000),
	        @"explicit": @(isExplicit),
	        @"fileExtension": ext?:@"",
	        @"gapless": @NO,
	        @"genre": genre?:@"",
	         //@"genreId": @(14),
	        @"isMasteredForItunes": @NO,
	        @"itemId": @(itemID),
	        @"itemName": title?:@"",
	        @"kind": kindType?:@"",
	        @"playlistArtistName": artist?:@"",
	         //@"playlistId": @(itemID),
	        @"playlistName": album?:@"",
	         //@"rank": @(1),
	        @"releaseDate": [NSDate date],
	         //@"s": @(143444),
	         //@"sampleRate": @(44100),
	        @"sort-album": album?:@"",
	        @"sort-artist": artist?:@"",
	        @"sort-composer": composer?:@"",
	        @"sort-name": title?:@"",
	        @"trackCount": @(trackCount),
	        @"trackNumber": @(trackNumber),
	         //@"vendorId": @(1883),
	         //@"versionRestrictions": @(16873077),
	         //@"xid": @"Universal:isrc:NZUM71300248",
	        @"year": @(year),
		},
	};
	
	//NSLog(@"*** SSDownloadMetadata: %@", payloadImport);
	
	SSDownloadMetadata *metad = [[SSDownloadMetadata alloc] initWithDictionary:payloadImport];
	
	SSDownload *downl = [[SSDownload alloc] initWithDownloadMetadata:metad];
	
	
	SSDownloadQueue *dlQueue = [[SSDownloadQueue alloc] initWithDownloadKinds:[SSDownloadQueue mediaDownloadKinds]];
	[dlQueue addDownload:downl];
	
	
	
	
	//SSDownloadManager* dlMan = [SSDownloadManager IPodDownloadManager];	
	//[dlMan addDownloads:@[downl] completionBlock:nil];
	
	
	}
	} @catch (NSException * e) {
	}
}

@implementation MImportDropboxController
{
	//UIView *viewW;
}
@synthesize webView, startURL, returnURL, access_token, oldView, pathDir, contents, hud;
@dynamic loadingView;

- (void)loadLogin
{
	NSString* oauth_consumer_key = @"3wg57gho3rco3lb";
	
	self.returnURL = [[@"db-" stringByAppendingString:oauth_consumer_key] stringByAppendingString:@"://2/token"];
	self.startURL = [NSString stringWithFormat:@"https://www.dropbox.com/1/oauth2/authorize?response_type=token&client_id=%@&redirect_uri=%@&disable_signup=true", oauth_consumer_key, self.returnURL];
	if(!webView) {
		webView = [[UIWebView alloc] initWithFrame:CGRectZero];
		webView.delegate = self;
		[webView setAutoresizingMask:(UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight)];
	}
	self.view = webView;
	if(!webView.loading) {
		[webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:startURL]]];
	}
}

- (void)refreshToken
{
	NSData* credData = [[NSUserDefaults standardUserDefaults] objectForKey:@"MImport-db-access_token"]?:nil;
	self.access_token = credData?[[NSString alloc] initWithData:credData encoding:NSUTF8StringEncoding]:nil;
}
- (void)checkLogin
{
	if(self.view && ![self.view isKindOfClass:[UIWebView class]]) {
		oldView = self.view;
	}
	
	[self refreshToken];
	
	if(!(self.access_token && self.access_token.length > 0)) {
		[self loadLogin];
	} else {
		if(oldView && oldView != self.view) {
			self.view = oldView;			
		}
		[self.view layoutSubviews];
		[self.tableView layoutSubviews];
	}
	[self updateButtons];
}

- (void)updateButtons
{
	if(self.access_token && self.access_token.length > 0) {
		self.title = [pathDir?:@"Dropbox" lastPathComponent];
	}
	UIBarButtonItem *button = (self.access_token && self.access_token.length > 0)?[[UIBarButtonItem alloc] initWithTitle:@"•••" style:UIBarButtonItemStylePlain target:self action:@selector(showOptions)]:[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(Reload)];
	
	__strong UIBarButtonItem* kBTClose = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:self action:@selector(closeMImport)];
	kBTClose.tag = 4;
	
	self.navigationItem.rightBarButtonItems = @[kBTClose, button];
	
}
- (void)closeMImport
{
	[self dismissViewControllerAnimated:YES completion:nil];
}
- (void)saveTokens
{
	if(!self.access_token) {
		return;
	}
	@autoreleasepool {
		[[NSUserDefaults standardUserDefaults] setObject:[self.access_token dataUsingEncoding:NSUTF8StringEncoding] forKey:@"MImport-db-access_token"];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
	[self checkLogin];
}
- (void)loadView
{
	[super loadView];
	
	self.title = [pathDir?:@"Dropbox" lastPathComponent];
	
	contents = @[];
	
	[self refreshToken];
	
	[self getCurrentPath];
	
	
	//[self checkLogin];
}
- (void)viewDidLoad
{
    [super viewDidLoad];
	
	UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
	[refreshControl addTarget:self action:@selector(refreshView:) forControlEvents:UIControlEventValueChanged];
	[self.tableView addSubview:refreshControl];
}

- (void)showOptions
{
	NSString* cancelSt = [[NSBundle bundleWithPath:@"/System/Library/Frameworks/UIKit.framework"]?:[NSBundle mainBundle] localizedStringForKey:@"Cancel" value:@"Cancel" table:nil];
	NSString* logoutSt = @"Logout Account";
	
	if(%c(UIAlertController) != nil) {
		UIAlertController *alert = [%c(UIAlertController) alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
		actionShetModel* model = [[actionShetModel alloc] init];
		[model setContext:@"more"];	
		UIAlertAction* actionLogout = [%c(UIAlertAction) actionWithTitle:logoutSt style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
			model.buttonName = logoutSt;
			[self actionSheet:(UIActionSheet *)model clickedButtonAtIndex:1];
		}];
		[alert addAction:actionLogout];
		UIAlertAction *cancel = [%c(UIAlertAction) actionWithTitle:cancelSt style:UIAlertActionStyleCancel handler:nil];
		[alert addAction:cancel];
		[self presentViewController:alert animated:YES completion:nil];
	} else {
		UIActionSheet *popup = [[%c(UIActionSheet) alloc] initWithTitle:nil delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
		[popup setContext:@"more"];	
		
		[popup addButtonWithTitle:logoutSt];
		
		[popup addButtonWithTitle:cancelSt];
		[popup setCancelButtonIndex:[popup numberOfButtons] - 1];
		if (isDeviceIPad) {
			[popup showFromBarButtonItem:[[self navigationItem] rightBarButtonItem] animated:YES];
		} else {
			[popup showInView:self.view];
		}
	}
}



#define LOADING_TAG 6543
-(UIActivityIndicatorView *)loadingView
{
	UIActivityIndicatorView *lv = (UIActivityIndicatorView *)[self.view viewWithTag:LOADING_TAG];
	if (lv == nil) {
		lv = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
		[lv setHidesWhenStopped:TRUE];
		lv.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.6f];
		[lv setColor:[UIColor whiteColor]];
		lv.layer.cornerRadius = 05;
		lv.opaque = NO;
		lv.center = self.view.center;
		lv.tag = LOADING_TAG;
		[self.view addSubview:lv];
	}
	return lv;
}

- (void)Reload
{
	if(self.view == webView) {
		[webView reload];
	}
}
-(void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	[[MImportTapMenu sharedInstance] _deviceOrientationDidChange];
	[self loadingView];
	[self checkLogin];
}
-(void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
}
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}
- (void)dealloc
{
	self.startURL = nil;
	self.returnURL = nil;
	if(self.view && [self.view respondsToSelector:@selector(delegate)]) {
		((UIWebView *)self.view).delegate = nil;
	}
}
- (void)receiveURLToken:(NSString*)URLToken
{
	NSURL* urlTK = [NSURL URLWithString:URLToken];
	NSString* queryst = [urlTK fragment];
	if(!queryst) {
		return;
	}
	NSMutableDictionary *queryStringDictionary = [[NSMutableDictionary alloc] init];
	NSArray *urlComponents = [queryst componentsSeparatedByString:@"&"];
	for (NSString *keyValuePair in urlComponents) {
		NSArray *pairComponents = [keyValuePair componentsSeparatedByString:@"="];
		NSString *key = [[pairComponents firstObject] stringByRemovingPercentEncoding];
		NSString *value = [[pairComponents lastObject] stringByRemovingPercentEncoding];
		[queryStringDictionary setObject:value forKey:key];
	}
	self.access_token = [queryStringDictionary objectForKey:@"access_token"]?:self.access_token;
	[self saveTokens];
	[self getCurrentPath];
}
- (void)showError:(NSString*)error
{
	dispatch_async(dispatch_get_main_queue(), ^(void) {
		NSString* titleSt = @"Error";
		NSString* messageSt = error;
		NSString* okSt = @"OK";
		
		if(%c(UIAlertController) != nil) {
			UIAlertController* alert = [%c(UIAlertController) alertControllerWithTitle:titleSt message:messageSt preferredStyle:UIAlertControllerStyleAlert];
			UIAlertAction* defaultAction = [%c(UIAlertAction) actionWithTitle:okSt style:UIAlertActionStyleDefault handler:nil];
			[alert addAction:defaultAction];
			[topMostController() presentViewController:alert animated:YES completion:nil];
		} else {
			UIAlertView *alert = [[%c(UIAlertView) alloc] initWithTitle:titleSt message:messageSt delegate:nil cancelButtonTitle:okSt otherButtonTitles:nil];
			[alert show];
		}
	});
}

- (NSMutableURLRequest*)listRequest:(NSString*)path
{
	NSString* url_reqA = [[@"https://api.dropbox.com/2" stringByAppendingPathComponent:@"files"] stringByAppendingPathComponent:@"list_folder"];
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
	[request setURL:[NSURL URLWithString:url_reqA]];
	[request setHTTPMethod:@"POST"];
	[request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
	[request setValue:@"OfficialDropboxObjCSDKv2/3.1.1" forHTTPHeaderField:@"User-Agent"];
	[request setValue:[NSString stringWithFormat:@"Bearer %@", self.access_token] forHTTPHeaderField:@"Authorization"];
	
	//[request setValue:[NSString stringWithFormat:@"{\"path\":\"%@\"}", file] forHTTPHeaderField:@"Dropbox-API-Arg"];
	
	[request setHTTPBody:[NSJSONSerialization dataWithJSONObject:@{
	@"path": path?:@"",
	@"include_media_info": @NO,
	@"include_deleted": @NO,
	@"include_has_explicit_shared_members": @NO,
	@"recursive": @NO,
	} options:0 error:nil]];
	
	return request;
}

- (NSMutableURLRequest*)getLinkRequest:(NSString*)file
{
	NSString* url_reqA = [[@"https://api.dropbox.com/2" stringByAppendingPathComponent:@"files"] stringByAppendingPathComponent:@"get_temporary_link"];
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
	[request setURL:[NSURL URLWithString:url_reqA]];
	[request setHTTPMethod:@"POST"];
	[request setValue:[NSString stringWithFormat:@"Bearer %@", self.access_token] forHTTPHeaderField:@"Authorization"];
	[request setValue:@"OfficialDropboxObjCSDKv2/3.1.1" forHTTPHeaderField:@"User-Agent"];
	[request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
	
	NSString* fileEncode = [NSString stringWithFormat:@"%@", @{@"":file}];
	fileEncode = [fileEncode substringToIndex:[fileEncode length]-3];
	fileEncode = [fileEncode substringFromIndex:11];
	if([fileEncode hasPrefix:@"\""] && [fileEncode hasSuffix:@"\""]) {
		fileEncode = [fileEncode substringToIndex:[fileEncode length]-1];
		fileEncode = [fileEncode substringFromIndex:1];
	}
	fileEncode = [fileEncode stringByReplacingOccurrencesOfString: @"\\U" withString:@"\\u"];
	
	[request setHTTPBody:[[NSString stringWithFormat:@"{\"path\":\"%@\"}", fileEncode] dataUsingEncoding:NSUTF8StringEncoding]];
	
	return request;
}

- (NSMutableURLRequest*)downloadRequest:(NSString*)file
{
	NSString* url_reqA = [[@"https://api-content.dropbox.com/2" stringByAppendingPathComponent:@"files"] stringByAppendingPathComponent:@"download"];
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
	[request setURL:[NSURL URLWithString:url_reqA]];
	[request setHTTPMethod:@"POST"];
	[request setValue:[NSString stringWithFormat:@"Bearer %@", self.access_token] forHTTPHeaderField:@"Authorization"];
	[request setValue:@"OfficialDropboxObjCSDKv2/3.1.1" forHTTPHeaderField:@"User-Agent"];
	
	NSString* fileEncode = [NSString stringWithFormat:@"%@", @{@"":file}];
	fileEncode = [fileEncode substringToIndex:[fileEncode length]-3];
	fileEncode = [fileEncode substringFromIndex:11];
	if([fileEncode hasPrefix:@"\""] && [fileEncode hasSuffix:@"\""]) {
		fileEncode = [fileEncode substringToIndex:[fileEncode length]-1];
		fileEncode = [fileEncode substringFromIndex:1];
	}
	fileEncode = [fileEncode stringByReplacingOccurrencesOfString: @"\\U" withString:@"\\u"];
	
	[request setValue:[NSString stringWithFormat:@"{\"path\":\"%@\"}", fileEncode] forHTTPHeaderField:@"Dropbox-API-Arg"];
	
	
	return request;
}
- (NSMutableURLRequest*)uploadRequest:(NSString*)file
{
	NSString* url_reqA = [[@"https://api-content.dropbox.com/2" stringByAppendingPathComponent:@"files"] stringByAppendingPathComponent:@"upload"];
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
	[request setURL:[NSURL URLWithString:url_reqA]];
	[request setHTTPMethod:@"POST"];
	[request setValue:[NSString stringWithFormat:@"Bearer %@", self.access_token] forHTTPHeaderField:@"Authorization"];
	[request setValue:@"OfficialDropboxObjCSDKv2/3.1.1" forHTTPHeaderField:@"User-Agent"];
	
	NSString* fileEncode = [NSString stringWithFormat:@"%@", @{@"":file}];
	fileEncode = [fileEncode substringToIndex:[fileEncode length]-3];
	fileEncode = [fileEncode substringFromIndex:11];
	if([fileEncode hasPrefix:@"\""] && [fileEncode hasSuffix:@"\""]) {
		fileEncode = [fileEncode substringToIndex:[fileEncode length]-1];
		fileEncode = [fileEncode substringFromIndex:1];
	}
	fileEncode = [fileEncode stringByReplacingOccurrencesOfString: @"\\U" withString:@"\\u"];
	
	[request setValue:[NSString stringWithFormat:@"{\"path\":\"%@\",\"autorename\":false,\"mute\":false,\"mode\":{\".tag\":\"overwrite\"}}", fileEncode] forHTTPHeaderField:@"Dropbox-API-Arg"];
	[request setValue:@"application/octet-stream" forHTTPHeaderField:@"Content-Type"];
	return request;
}

- (void)getCurrentPath
{
	if(!(self.access_token && self.access_token.length > 0)) {
		contents = @[];
		[self.tableView reloadData];
		return;
	}
	if(!self.hud) {
		hud = [[UIProgressHUD alloc] init];
	}
	[hud setText:@"Loading Contents..."];
	[hud showInView:self.view];
	[self.view setUserInteractionEnabled:NO];
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		@try{
			NSMutableURLRequest* request = [self listRequest:pathDir];
			NSError* error = nil;
			NSURLResponse* imageresponse_link = nil;
			NSHTTPURLResponse *httpResponse_link = nil;
			__autoreleasing NSData *imageresult_link = [NSURLConnection sendSynchronousRequest:request returningResponse:&imageresponse_link error:&error];
			httpResponse_link = (NSHTTPURLResponse*)imageresponse_link;
			if(error) {
				[self showError:[error localizedDescription]];
				if((httpResponse_link && httpResponse_link.statusCode == 401) || (error.code == kCFURLErrorUserCancelledAuthentication)) {
					[self loadLogin];
				}
			}

			NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:imageresult_link?:[NSData data] options:kNilOptions error:nil]?:@{};
			contents = [dictionary[@"entries"]?:@[] copy];
			
			dispatch_async(dispatch_get_main_queue(), ^(void) {
				[self.view setUserInteractionEnabled:YES];
				[hud hide];
				[self.tableView reloadData];
			});
			
		}@catch(NSException* ex) {
		}
	});
}

- (void)refreshView:(UIRefreshControl *)refresh
{
	[self getCurrentPath];
	[refresh endRefreshing];
}

- (void)getLinkDownload:(NSString*)path hash:(NSString*)contentHash
{
	if(!self.hud) {
		hud = [[UIProgressHUD alloc] init];
	}
	[hud setText:@"Loading..."];
	[hud showInView:self.view];
	[self.view setUserInteractionEnabled:NO];
	__block NSString* linkGetSt;
	linkGetSt = nil;
	__block NSString* fileExSt;
	fileExSt = nil;
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		NSMutableURLRequest* request = [self getLinkRequest:path];
		NSError* error = nil;
		NSURLResponse* imageresponse_link = nil;
		NSHTTPURLResponse *httpResponse_link = nil;
		__autoreleasing NSData *imageresult_link = [NSURLConnection sendSynchronousRequest:request returningResponse:&imageresponse_link error:&error];
		httpResponse_link = (NSHTTPURLResponse*)imageresponse_link;
		if(error) {
			[self showError:[error localizedDescription]];
			if((httpResponse_link && httpResponse_link.statusCode == 401) || (error.code == kCFURLErrorUserCancelledAuthentication)) {
				[self loadLogin];
			}
		}
		if(httpResponse_link.statusCode == 200 && imageresult_link) {
			
			NSDictionary *dictionaryJS = [NSJSONSerialization JSONObjectWithData:imageresult_link options:0 error:nil]?:@{};
			
			fileExSt = [contentHash?:@"" pathExtension];
			linkGetSt = dictionaryJS[@"link"];
			
		} else if (httpResponse_link.statusCode == 404) {
			[self showError:@"File Not Found."];
		} else {
			[self showError:@"Unknown Error"];
		}
		
		dispatch_async(dispatch_get_main_queue(), ^(void) {
			[self.view setUserInteractionEnabled:YES];
			[hud hide];
			[self.tableView reloadData];
			@try {
				if(linkGetSt) {
					[self.navigationController pushViewController:[[%c(MImportEditTagListController) alloc] initWithURL:fixedMImportURLCachedWithURL([NSURL URLWithString:linkGetSt], fileExSt)] animated:YES];
				}
			} @catch (NSException * e) {
			}
		});
	});
}

- (void)downloadFileAtPath:(NSString*)path hash:(NSString*)contentHash
{
	if(!self.hud) {
		hud = [[UIProgressHUD alloc] init];
	}
	[hud setText:@"Downloading..."];
	[hud showInView:self.view];
	[self.view setUserInteractionEnabled:NO];
	__block BOOL hasDownload;
	hasDownload = NO;
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		NSMutableURLRequest* request = [self downloadRequest:path];
		NSError* error = nil;
		NSURLResponse* imageresponse_link = nil;
		NSHTTPURLResponse *httpResponse_link = nil;
		__autoreleasing NSData *imageresult_link = [NSURLConnection sendSynchronousRequest:request returningResponse:&imageresponse_link error:&error];
		httpResponse_link = (NSHTTPURLResponse*)imageresponse_link;
		if(error) {
			[self showError:[error localizedDescription]];
			if((httpResponse_link && httpResponse_link.statusCode == 401) || (error.code == kCFURLErrorUserCancelledAuthentication)) {
				[self loadLogin];
			}
		}
		if(httpResponse_link.statusCode == 200 && imageresult_link) {
			[imageresult_link writeToFile:[NSTemporaryDirectory() stringByAppendingPathComponent:contentHash] atomically:YES];
			hasDownload = YES;
		} else if (httpResponse_link.statusCode == 404) {
			[self showError:@"File Not Found."];
		} else {
			[self showError:@"Unknown Error"];
		}
		
		dispatch_async(dispatch_get_main_queue(), ^(void) {
			[self.view setUserInteractionEnabled:YES];
			[hud hide];
			[self.tableView reloadData];
			@try {
				if(hasDownload) {
					[self.navigationController pushViewController:[[%c(MImportEditTagListController) alloc] initWithURL:fixURLRemoteOrLocalWithPath([NSTemporaryDirectory() stringByAppendingPathComponent:contentHash])] animated:YES];
				}
			} @catch (NSException * e) {
			}
		});
	});
}

#pragma mark UIWebViewDelegate methods
- (BOOL)webView:(UIWebView *)webViewA shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
	NSString *urlString = [[request.URL absoluteString] lowercaseString];
	if (urlString && urlString.length>0) {
		if ([urlString hasPrefix:[returnURL lowercaseString]]) {
			[self receiveURLToken:[request.URL absoluteString]];
			return FALSE;
		}
	}
	return TRUE;
}
- (void)webViewDidStartLoad:(UIWebView *)webView
{
	self.title = [[[NSBundle mainBundle] localizedStringForKey:@"LOADING" value:@"Loading" table:nil] stringByAppendingString:@"..."];
	[self.loadingView startAnimating];
}
- (void)webViewDidFinishLoad:(UIWebView *)webViewA
{
	self.title = [webViewA stringByEvaluatingJavaScriptFromString:@"document.title"];
	[self.loadingView stopAnimating];
	if([webViewA stringByEvaluatingJavaScriptFromString:@"document.getElementsByClassName('app-name')[0].innerHTML = \"MImport\";"] != nil) {
		//
	}
	if([webViewA stringByEvaluatingJavaScriptFromString:@"document.getElementById('app-icon').src = \"https://i.imgur.com/ywNVvSR.png\";"] != nil) {
		//
	}
}
- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
	[self.loadingView stopAnimating];
	if(error.code == 102 || error.code == -999) {
		return;
	}
	[self.navigationController popViewControllerAnimated:TRUE];
	self.title = @"Connection failed";
	[self showError:[error localizedDescription]];
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [contents count];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
	cell.textLabel.text = nil;
	cell.detailTextLabel.text = nil;
	cell.imageView.image = nil;
	cell.accessoryType = UITableViewCellAccessoryNone;
	
	@try {
		if(indexPath.section == 0) {
			NSDictionary* selContent = contents[indexPath.row];
			if([selContent[@".tag"]?:@"" isEqualToString:@"folder"]) {
				cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
				cell.imageView.image = kImageDirGet();
			} else {
				if(id sizeId = selContent[@"size"]) {
					cell.detailTextLabel.text = formatFileSizeFromBytes([sizeId intValue]);
				}
				cell.imageView.image = kIconMimportGet();
			}
			cell.textLabel.text = selContent[@"name"];
		}
	} @catch (NSException * e) {
	}
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:NO];
	@try {
		NSDictionary* selContent = contents[indexPath.row];
		if([selContent[@".tag"]?:@"" isEqualToString:@"folder"]) {
			MImportDropboxController* DBController = [[MImportDropboxController alloc] initWithStyle:UITableViewStyleGrouped];
			DBController.pathDir = selContent[@"path_lower"];
			[self.navigationController pushViewController:DBController animated:YES];
		} else {
			NSString* cancelSt = [[NSBundle bundleWithPath:@"/System/Library/Frameworks/UIKit.framework"]?:[NSBundle mainBundle] localizedStringForKey:@"Cancel" value:@"Cancel" table:nil];
			NSString* importSt = [[NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/PhotoLibrary.framework"]?:[NSBundle mainBundle] localizedStringForKey:@"IMPORT" value:@"Import" table:@"PhotoLibrary"];
			NSString* playSt = @"Play";
			NSString* deleteSt = [[NSBundle bundleWithPath:@"/System/Library/Frameworks/UIKit.framework"]?:[NSBundle mainBundle] localizedStringForKey:@"Delete" value:@"Delete" table:nil];
			NSString* downloadSt = @"Download";
			NSString* importNowSt = @"Import Now";
			
			if(%c(UIAlertController) != nil) {
				UIAlertController *alert = [%c(UIAlertController) alertControllerWithTitle:selContent[@"name"] message:nil preferredStyle:UIAlertControllerStyleActionSheet];
				actionShetModel* model = [[actionShetModel alloc] init];
				[model setContext:@"file"];
				model.tag = indexPath.row;
				if ([[NSFileManager defaultManager] fileExistsAtPath:[NSTemporaryDirectory() stringByAppendingPathComponent:selContent[@"name"]?:@""]]) {
					UIAlertAction* actionImport = [%c(UIAlertAction) actionWithTitle:importNowSt style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
						model.buttonName = importNowSt;
						[self actionSheet:(UIActionSheet *)model clickedButtonAtIndex:1];
					}];
					[alert addAction:actionImport];
					UIAlertAction* actionPlay = [%c(UIAlertAction) actionWithTitle:playSt style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
						model.buttonName = playSt;
						[self actionSheet:(UIActionSheet *)model clickedButtonAtIndex:1];
					}];
					[alert addAction:actionPlay];
					UIAlertAction* actionDel = [%c(UIAlertAction) actionWithTitle:deleteSt style:UIAlertActionStyleDestructive handler:^(UIAlertAction * action) {
						model.buttonName = deleteSt;
						[self actionSheet:(UIActionSheet *)model clickedButtonAtIndex:1];
					}];
					[alert addAction:actionDel];
				} else {
					UIAlertAction* actionDown = [%c(UIAlertAction) actionWithTitle:downloadSt style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
						model.buttonName = downloadSt;
						[self actionSheet:(UIActionSheet *)model clickedButtonAtIndex:1];
					}];
					[alert addAction:actionDown];
					UIAlertAction* actionImport = [%c(UIAlertAction) actionWithTitle:importNowSt style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
						model.buttonName = importNowSt;
						[self actionSheet:(UIActionSheet *)model clickedButtonAtIndex:1];
					}];
					[alert addAction:actionImport];
				}				
				UIAlertAction *cancel = [%c(UIAlertAction) actionWithTitle:cancelSt style:UIAlertActionStyleCancel handler:nil];
				[alert addAction:cancel];
				[self presentViewController:alert animated:YES completion:nil];
			} else {
				UIActionSheet *popup = [[%c(UIActionSheet) alloc] initWithTitle:selContent[@"name"] delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
				[popup setContext:@"file"];
				popup.tag = indexPath.row;
				if ([[NSFileManager defaultManager] fileExistsAtPath:[NSTemporaryDirectory() stringByAppendingPathComponent:selContent[@"name"]?:@""]]) {
					[popup addButtonWithTitle:importSt];
					[popup addButtonWithTitle:playSt];
					[popup setDestructiveButtonIndex:[popup addButtonWithTitle:deleteSt]];
				} else {
					[popup addButtonWithTitle:downloadSt];
					[popup addButtonWithTitle:importNowSt];
				}				
				[popup addButtonWithTitle:cancelSt];
				[popup setCancelButtonIndex:[popup numberOfButtons] - 1];
				if (isDeviceIPad) {
					[popup showFromBarButtonItem:[[self navigationItem] rightBarButtonItem] animated:YES];
				} else {
					[popup showInView:self.view];
				}
			}
		}
	} @catch (NSException * e) {
	}
}

- (void)actionSheet:(UIActionSheet *)alert clickedButtonAtIndex:(NSInteger)button 
{
	NSString* contextAlert = [alert context];
	NSString* buttonTitle = [[alert buttonTitleAtIndex:button] copy];
	
	if (button == [alert cancelButtonIndex]) {
		return;
	}
	if(contextAlert&&[contextAlert isEqualToString:@"more"]) {
		
		if ([buttonTitle isEqualToString:@"Logout Account"]) {
			@autoreleasepool {
				[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"MImport-db-access_token"];
				[[NSUserDefaults standardUserDefaults] synchronize];
			}
			[self checkLogin];
		}
		
		return;
	} else if(contextAlert&&[contextAlert isEqualToString:@"file"]) {
		NSDictionary* selContent = contents[alert.tag];
		
		if([buttonTitle isEqualToString:@"Play"]) {
			playFromURLWithViewController(self, [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:selContent[@"name"]?:@""]]);
			return;
		} else if ([buttonTitle isEqualToString:@"Import Now"]) {
			[self getLinkDownload:selContent[@"path_lower"] hash:selContent[@"name"]?:@""];
		} else if ([buttonTitle isEqualToString:@"Download"]) {
			[self downloadFileAtPath:selContent[@"path_lower"] hash:selContent[@"name"]?:@""];
		} else if ([buttonTitle isEqualToString:[[NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/PhotoLibrary.framework"]?:[NSBundle mainBundle] localizedStringForKey:@"IMPORT" value:@"Import" table:@"PhotoLibrary"]]) {
			@try {
				[self.navigationController pushViewController:[[%c(MImportEditTagListController) alloc] initWithURL:fixURLRemoteOrLocalWithPath([NSTemporaryDirectory() stringByAppendingPathComponent:selContent[@"name"]?:@""])] animated:YES];
			} @catch (NSException * e) {
			}
		} else if ([buttonTitle isEqualToString:[[NSBundle bundleWithPath:@"/System/Library/Frameworks/UIKit.framework"]?:[NSBundle mainBundle] localizedStringForKey:@"Delete" value:@"Delete" table:nil]]) {
			NSError* error = nil;
			[[NSFileManager defaultManager] removeItemAtPath:[NSTemporaryDirectory() stringByAppendingPathComponent:selContent[@"name"]?:@""] error:&error];
			if(error) {
				[self showError:[error localizedDescription]];
			}
		}
		return;
	}
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
	if(section == [self numberOfSectionsInTableView:tableView]-1) {
		return getHeaderName();
	}
	return [super tableView:tableView titleForFooterInSection:section];
}

- (NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	return self.pathDir?:@" ";
}
- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section
{
    if([view isKindOfClass:[UITableViewHeaderFooterView class]]) {
        UITableViewHeaderFooterView *tableViewHeaderFooterView = (UITableViewHeaderFooterView *) view;
        tableViewHeaderFooterView.textLabel.text = self.pathDir?:@" ";
    }
}
@end


static __strong UINavigationController *navCon;

@implementation MImportTapMenu
@synthesize pathFav = _pathFav;
- (int)extraHeightTabBar
{
	@try {
		if(((UIWindow *)[[UIApplication sharedApplication] keyWindow]).safeAreaInsets.bottom > 0) {
			return 34;
		}
	} @catch(NSException *e) {
		return 0;
	}
	return 0;
}
+ (id)sharedInstance
{
	static __strong MImportTapMenu* shared;
	if(!shared) {
		shared = [[[self class] alloc] init];
		[[NSNotificationCenter defaultCenter] addObserver:shared selector:@selector(deviceOrientationDidChange) name:UIDeviceOrientationDidChangeNotification object:nil];
	}
	return shared;
}
- (void)deviceOrientationDidChange
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_deviceOrientationDidChange) object:nil];
	[self performSelector:@selector(_deviceOrientationDidChange) withObject:nil afterDelay:0];
	[self performSelector:@selector(_deviceOrientationDidChange) withObject:nil afterDelay:1];
}
- (void)_deviceOrientationDidChange
{
	if(!navCon) {
		return;
	}
	if(UIView* tabVi = [navCon.view viewWithTag:548]) {
		[tabVi setFrame:CGRectMake(0, navCon.view.frame.size.height - (49+[self extraHeightTabBar]), navCon.view.frame.size.width, (50+[self extraHeightTabBar]))];
		[tabVi layoutSubviews];
	}
}
- (void)tabBar:(UITabBar *)tabBar didSelectItem:(UITabBarItem *)item
{
	@try{
		startServer();
    NSInteger selectedTag = tabBar.selectedItem.tag;
	
	if(selectedTag == 3) {
		[navCon setViewControllers:@[[MImportAppsController shared]] animated:NO];
		return;
	}
	if(selectedTag == 4) {
		[navCon setViewControllers:@[[MImportHistoryController shared]] animated:NO];
		return;
	}
	if(selectedTag == 2) {
		[navCon setViewControllers:@[[MImportFavoriteController shared]] animated:NO];
		return;
	}
	
	MImportDirBrowserController *dbtvc = [[[MImportDirBrowserController alloc] init] initWithStyle:UITableViewStyleGrouped];
	dbtvc.path = @"/";
	[navCon setViewControllers:@[dbtvc] animated:NO];
	NSString* current_pt = @"/";
	NSString* patFav;
	if(selectedTag == 1) {
		patFav = @"/var/mobile/";
    }
	for(NSString*path_now in [patFav componentsSeparatedByString:@"/"]) {
		if(path_now && [path_now length] > 0) {
			MImportDirBrowserController *dbtvc1 = [[[MImportDirBrowserController alloc] init] initWithStyle:UITableViewStyleGrouped];
			current_pt = [current_pt stringByAppendingPathComponent:path_now];
			dbtvc1.path = current_pt;
			[navCon pushViewController:dbtvc1 animated:NO];
		}
	}
	} @catch (NSException * e) {
	}
}
- (void)applyTabBarNavController:(UINavigationController*)navc
{
	@try{
		float y = navCon.view.frame.size.height - 49;
		if(UIView* tabVi = [navCon.view viewWithTag:548]) {
			[tabVi removeFromSuperview];
		}
		UITabBar *myTabBar = [[UITabBar alloc] initWithFrame:CGRectMake(0, y, 320, 50)];
		myTabBar.delegate = self;
		myTabBar.tag = 548;
		
		
		
		[navCon.view addSubview:myTabBar];
		[myTabBar setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
		[myTabBar setFrame:CGRectMake(0, y, navCon.view.frame.size.width, myTabBar.frame.size.height)];
		UITabBarItem *tabBarItem1 = [[UITabBarItem alloc] initWithTitle:@"/" image:[[UIImage alloc] initWithContentsOfFile:[[NSBundle bundleWithPath:@"/Library/PreferenceBundles/MImport.bundle"]?:[NSBundle mainBundle] pathForResource:@"dir" ofType:@"png"]] tag:0];
		UITabBarItem *tabBarItem2 = [[UITabBarItem alloc] initWithTitle:@"mobile" image:[[UIImage alloc] initWithContentsOfFile:[[NSBundle bundleWithPath:@"/Library/PreferenceBundles/MImport.bundle"]?:[NSBundle mainBundle] pathForResource:@"dir" ofType:@"png"]] tag:1];
		UITabBarItem *tabBarItem3 = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemFavorites tag:2];
		UITabBarItem *tabBarItem5 = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemBookmarks tag:3];
		[tabBarItem5 _setInternalTitle:@"Applications"];
		UITabBarItem *tabBarItem6 = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemHistory tag:4];
		myTabBar.items = @[tabBarItem5, tabBarItem1, tabBarItem2, tabBarItem3, tabBarItem6];
		myTabBar.selectedItem = [myTabBar.items objectAtIndex:2];
		[self tabBar:myTabBar didSelectItem:myTabBar.selectedItem];
		
		[self _deviceOrientationDidChange];
	} @catch (NSException * e) {
	}
}
- (void)actionSheet:(UIActionSheet *)alert clickedButtonAtIndex:(NSInteger)button 
{
	@try {
		if (button == [alert cancelButtonIndex]) {
			return;
		} else if(self.pathFav) {
			NSMutableDictionary* mutFavs = [[[NSUserDefaults standardUserDefaults] objectForKey:@"MImport-allFavURLs"]?:@{} mutableCopy];
			mutFavs[self.pathFav] = @{@"name": [self.pathFav lastPathComponent], @"path": self.pathFav};
			[[NSUserDefaults standardUserDefaults] setObject:mutFavs forKey:@"MImport-allFavURLs"];
			[[NSUserDefaults standardUserDefaults] synchronize];		
		}
	} @catch (NSException * e) {
	}
}
- (void)closePopUp
{
	if(!navCon) {
		return;
	}
	[navCon dismissModalViewControllerAnimated:YES];
}
@end

static void launchMImportNow()
{
	@try {
		MImportDirBrowserController *dbtvc = [[[MImportDirBrowserController alloc] init] initWithStyle:UITableViewStyleGrouped];
		dbtvc.path = @"/";		
		if(!navCon) {
			navCon = [[UINavigationController alloc] initWithNavigationBarClass:[UINavigationBar class] toolbarClass:[UIToolbar class]];
		}		
		[navCon setViewControllers:@[dbtvc] animated:NO];
		[[MImportTapMenu sharedInstance] applyTabBarNavController:navCon];
		
		[topMostController() presentViewController:navCon animated:YES completion:nil];
	} @catch (NSException * e) {
	}
}


@interface UIColor ()
+ (id)labelColor;
@end

@implementation MImportUploadController

+ (instancetype)sharedInstance
{
	static __strong MImportUploadController* _shared;
	if(!_shared) {
		_shared = [[[self class] alloc] initWithStyle:UITableViewStyleGrouped];
	}
	return _shared;
}

- (id)initWithStyle:(UITableViewStyle)style
{
	if(self = [super initWithStyle:style]) {
		
	}
	return self;
}
- (void)setRightButton
{
	__strong UIBarButtonItem* kBTClose = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:self action:@selector(closeMImport)];
	kBTClose.tag = 4;
	self.navigationItem.rightBarButtonItems = @[kBTClose];	
}
- (void)closeMImport
{
	[self dismissViewControllerAnimated:YES completion:nil];
}
- (void)viewDidLoad
{
	[super viewDidLoad];
	[self setRightButton];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSString* simpleTableIdentifier = @"MImport";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:simpleTableIdentifier];
	if (cell == nil) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:simpleTableIdentifier];
	}
	cell.accessoryType = UITableViewCellAccessoryNone;
	[cell setSelectionStyle:UITableViewCellSelectionStyleNone];
	cell.accessoryView = nil;
	cell.imageView.image = nil;
	cell.textLabel.text = nil;
	cell.detailTextLabel.text = nil;
	
	UIColor* labC = nil;
	@try {
		labC = [UIColor labelColor];
	}@catch(NSException*e) {
		labC = [UIColor blackColor];
	}
	cell.textLabel.textColor = labC;
	
	if ([indexPath section] == 0) {
		if (indexPath.row == 0) {
			cell.textLabel.text = @"Enabled";
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
			UISwitch *switchView = [[UISwitch alloc] initWithFrame:CGRectZero];
			cell.accessoryView = switchView;
			[switchView setOn:(access(mimport_running_uploader, F_OK) == 0) animated:NO];
			[switchView addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
		}
	}
	
	return cell;
}
- (void)switchChanged:(id)sender
{
    UISwitch* switchControl = sender;
	if(switchControl.on) {
		close(open(mimport_running_uploader, O_CREAT));
	} else {
		unlink(mimport_running_uploader);
	}
	[self.tableView reloadData];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if (section == 0) {
		return 1;
	}
	return 0;
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}
- (NSString *)getIPAddress
{
    NSString *address = @"error";
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;
    success = getifaddrs(&interfaces);
    if (success == 0) {
        temp_addr = interfaces;
        while(temp_addr != NULL) {
            if(temp_addr->ifa_addr->sa_family == AF_INET) {
                if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                }
            }
            temp_addr = temp_addr->ifa_next;
        }
    }
    freeifaddrs(interfaces);
    return address;
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
	if (section == 0) {
		if(access(mimport_running_uploader, F_OK) == 0) {
			return [NSString stringWithFormat:@"Wi-Fi Sharing running at: http://%@:%@/", [self getIPAddress], @(PORT_SERVER_SHARE)];
		}
	}
	return nil;
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	return nil;
}
- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	[[MImportTapMenu sharedInstance] _deviceOrientationDidChange];
	self.title = @"Wi-Fi Sharing";
	[self.tableView reloadData];
	
}
- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
}
@end

@implementation MImportImportWithController
+ (id)shared
{
	static __strong MImportImportWithController* MImportImportWithControllerC;
	if(!MImportImportWithControllerC) {
		MImportImportWithControllerC = [[[self class] alloc] initWithStyle:UITableViewStyleGrouped];
	}
	return MImportImportWithControllerC;
}
- (void)setRightButton
{
	__strong UIBarButtonItem* kBTClose = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:self action:@selector(closeMImport)];
	kBTClose.tag = 4;
	self.navigationItem.rightBarButtonItems = @[kBTClose];	
}
- (void)closeMImport
{
	[self dismissViewControllerAnimated:YES completion:nil];
}
- (void)viewDidLoad
{
	[super viewDidLoad];
	[self setRightButton];
	self.title = @"Import From...";
}
- (void)viewWillAppear:(BOOL)arg1
{
	[super viewWillAppear:arg1];
	[[MImportTapMenu sharedInstance] _deviceOrientationDidChange];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1;
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 3;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
	cell.textLabel.text = nil;
	cell.detailTextLabel.text = nil;
	cell.imageView.image = nil;
	cell.accessoryType = UITableViewCellAccessoryNone;
	
	if(indexPath.section == 0) {
		cell.textLabel.text = @"URL or File Path";
		cell.detailTextLabel.text = @"Input Direct Media URL Or File Path";
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		cell.imageView.image = kIconMimportGet();
	} else if(indexPath.section == 1) {
		cell.textLabel.text = @"Wi-Fi Sharing";
		cell.detailTextLabel.text = @"Import Media From Web Server.";
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		cell.imageView.image = kIconMimportGet();
	} else if(indexPath.section == 2) {
		cell.textLabel.text = @"Dropbox";
		cell.detailTextLabel.text = @"Import Media From Dropbox.";
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		cell.imageView.image = kImageDirGet();
	}
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:NO];
	
	if(indexPath.section == 0) {
		NSString* cancelSt = [[NSBundle bundleWithPath:@"/System/Library/Frameworks/UIKit.framework"]?:[NSBundle mainBundle] localizedStringForKey:@"Cancel" value:@"Cancel" table:nil];
		NSString* inputSt = @"Input Direct Media URL Or File Path";
		if(%c(UIAlertController) != nil) {
			
			UIAlertController * alert = [%c(UIAlertController) alertControllerWithTitle:inputSt message:nil preferredStyle:UIAlertControllerStyleAlert];
			[alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
				textField.placeholder = [UIPasteboard generalPasteboard].string?:@"";
				//textField.textColor = [UIColor blueColor];
				textField.clearButtonMode = UITextFieldViewModeWhileEditing;
				textField.borderStyle = UITextBorderStyleRoundedRect;
			}];
			
			[alert addAction:[%c(UIAlertAction) actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
				NSArray * textfields = alert.textFields;
				UITextField * namefield = textfields[0];
				NSString* href = namefield.text?:[UIPasteboard generalPasteboard].string?:@"";
				@try {
					[self.navigationController pushViewController:[[%c(MImportEditTagListController) alloc] initWithURL:fixURLRemoteOrLocalWithPath(href)] animated:YES];
				} @catch (NSException * e) {
				}
			}]];
		
			UIAlertAction *cancel = [%c(UIAlertAction) actionWithTitle:cancelSt style:UIAlertActionStyleCancel handler:nil];
			[alert addAction:cancel];
			[self presentViewController:alert animated:YES completion:nil];
		} else {
			UIAlertView *alert = [[%c(UIAlertView) alloc] initWithTitle:inputSt message:nil delegate:self cancelButtonTitle:cancelSt otherButtonTitles:@"OK", nil];
			[alert setContext:@"importurl"];
			[alert setNumberOfRows:1];
			[alert addTextFieldWithValue:[UIPasteboard generalPasteboard].string?:@"" label:@""];
			UITextField *traitsF = [[alert textFieldAtIndex:0] textInputTraits];
			[traitsF setAutocapitalizationType:UITextAutocapitalizationTypeNone];
			[traitsF setAutocorrectionType:UITextAutocorrectionTypeNo];
			//[traitsF setKeyboardType:UIKeyboardTypeURL];
			[traitsF setReturnKeyType:UIReturnKeyNext];
			[alert show];
		}
	} else if(indexPath.section == 1) {
		@try {
			[self.navigationController pushViewController:[MImportUploadController sharedInstance] animated:YES];
		} @catch (NSException * e) {
		}
	} else if(indexPath.section == 2) {
		@try {
			[self.navigationController pushViewController:[[MImportDropboxController alloc] initWithStyle:UITableViewStyleGrouped] animated:YES];
		} @catch (NSException * e) {
		}
	}
}
- (void) alertView:(UIAlertView *)alert clickedButtonAtIndex:(NSInteger)button
{
	@try {
		NSString *context([alert context]);
		if(context&&[context isEqualToString:@"importurl"]) {
			if(button == 1) {
				NSString *href = [[alert textFieldAtIndex:0] text];
				@try {
					[self.navigationController pushViewController:[[%c(MImportEditTagListController) alloc] initWithURL:fixURLRemoteOrLocalWithPath(href)] animated:YES];
				} @catch (NSException * e) {
				}
			}
		}
	} @catch (NSException * e) {
	}
	[alert dismissWithClickedButtonIndex:-1 animated:YES];
}
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
	if(section == [self numberOfSectionsInTableView:tableView]-1) {
		return getHeaderName();
	}
	return [super tableView:tableView titleForFooterInSection:section];
}
@end

static void openImportFrom(UIViewController* instanceSelf)
{
	dispatch_async(dispatch_get_main_queue(), ^(void) {
		@try {
			[instanceSelf.navigationController pushViewController:[MImportImportWithController shared] animated:YES];
		} @catch (NSException * e) {
		}
	});
}

@interface UINavigationBar ()
- (void)launchMImport;
@end

%hook UINavigationBar
-(void)layoutSubviews
{
	%orig;
	BOOL hasButton = NO;
	for(UIBarButtonItem* now in self.topItem.rightBarButtonItems) {
		if (now.tag == 4) {
			hasButton = YES;
			break;
		}
	}
	
	if (!hasButton) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(callLaunchMImportFromURL) name:@"com.julioverne.mimport/callback" object:nil];
		__strong UIBarButtonItem* kBTLaunch = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemOrganize target:self action:@selector(launchMImport)];
		kBTLaunch.tag = 4;
		__autoreleasing NSMutableArray* BT = [self.topItem.rightBarButtonItems?:[NSArray array] mutableCopy];
		[BT addObject:kBTLaunch];
		self.topItem.rightBarButtonItems = [BT copy];
	}
}
%new
-(void)callLaunchMImportFromURL
{
	if(needShowAgainMImportURL) {
		needShowAgainMImportURL = NO;
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(launchMImportFromURL) object:receivedURLMImport];
		[self performSelector:@selector(launchMImportFromURL) withObject:receivedURLMImport afterDelay:1.5];
	}
}
%new
- (void)launchMImportFromURL
{
	if(!receivedURLMImport) {
		return;
	}
	[self launchMImport];
	/*dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			startServer();
			dispatch_async(dispatch_get_main_queue(), ^(void) {
				@try {
					MImportEditTagListController* NVBFromURL = [[%c(MImportEditTagListController) alloc] initWithURL:receivedURLMImport];
					NVBFromURL.isFromURL = YES;
					UINavigationController *navCon = [[UINavigationController alloc] initWithRootViewController:NVBFromURL];
					
					UIViewController *vc = [(UIWindow*)[UIApplication sharedApplication].delegate rootViewController];
					[vc presentViewController:navCon animated:YES completion:nil];
				} @catch (NSException * e) {
				}
			});
	});*/
}
%new
- (void)launchMImport
{
	if(isStartingServerInProgress) {
		return;
	}
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		startServer();
		dispatch_async(dispatch_get_main_queue(), ^(void) {
			launchMImportNow();
		});
	});
}
%end

static NSString * formatTimeFromSeconds(int numberOfSeconds)
{
	int seconds = numberOfSeconds % 60;
    int minutes = (numberOfSeconds / 60) % 60;
    int hours = numberOfSeconds / 3600;
	if(%c(NSDateComponentsFormatter)!=nil) {
		NSDateComponentsFormatter *dateComponentsFormatter = [%c(NSDateComponentsFormatter) new];
		dateComponentsFormatter.unitsStyle = NSDateComponentsFormatterUnitsStyleFull;
		return [dateComponentsFormatter stringFromTimeInterval:numberOfSeconds] ?: [NSString stringWithFormat:@"%ds", seconds];
	}
    if (hours) {
        return [NSString stringWithFormat:@"%dh:%02dm", hours, minutes];
    }
    if (minutes) {
        return [NSString stringWithFormat:@"%dm:%02ds", minutes, seconds];
    }
    return [NSString stringWithFormat:@"%ds", seconds];
}





@implementation MImportEditTagListController
@synthesize sourceURL = _sourceURL;
@synthesize tags = _tags;
@synthesize isFromURL = _isFromURL;
@synthesize showConvertTool, hud;
- (void)importFileNow
{
	receivedURLMImport = nil;
	[self.view endEditing:YES];
	if([self extSt].length == 0) {
		NSString* titleSt = self.title;
		NSString* messageSt = @"You need input file extension before import.";
		NSString* okSt = @"OK";
		
		if(%c(UIAlertController) != nil) {
			UIAlertController* alert = [%c(UIAlertController) alertControllerWithTitle:titleSt message:messageSt preferredStyle:UIAlertControllerStyleAlert];
			UIAlertAction* defaultAction = [%c(UIAlertAction) actionWithTitle:okSt style:UIAlertActionStyleDefault handler:nil];
			[alert addAction:defaultAction];
			[topMostController() presentViewController:alert animated:YES completion:nil];
		} else {
			UIAlertView *alert = [[%c(UIAlertView) alloc] initWithTitle:titleSt message:messageSt delegate:nil cancelButtonTitle:okSt otherButtonTitles:nil];
			[alert show];
		}
		return;
	}
	MImport_import(self.sourceURL, self.tags, NO);
	if(self.isFromURL) {
		[self dismissViewControllerAnimated:YES completion:nil];
	} else {
		[self.navigationController popViewControllerAnimated:YES];
	}	
}
- (NSString*)extSt
{
	return [self.tags[kExt]?:[[[self.sourceURL path] lastPathComponent]?:@"" pathExtension]?:@"" lowercaseString];
}
- (id)fileExt
{
	return self.tags[@"fileEX"]?:@"";
}
- (id)fileLocation
{
	return [NSString stringWithFormat:@"%@ (%@)", [self.sourceURL isFileURL]?@"Local":@"External", [self.sourceURL scheme]];
}
- (id)fileName
{
	return [[[self.sourceURL path] lastPathComponent]?:@"" stringByDeletingPathExtension]?:@"";
}
- (id)timeFormat
{
	return formatTimeFromSeconds([self.tags[kDuration]?:@(0) intValue]);
}
- (id)fileSizeFormat
{
	return formatFileSizeFromBytes([self.tags[kFileSize]?:@(0) intValue]);
}
- (id)initWithURL:(NSURL*)inURL
{
	self = [super init];
	startServer();
	if(self) {
		
		self.sourceURL = inURL;
		self.tags = [NSMutableDictionary dictionary];
		
		if(!self.hud) {
			self.hud = [[UIProgressHUD alloc] init];
		}
		[hud setText:@"Loading Tags..."];
		[hud showInView:self.view];
		[self.view setUserInteractionEnabled:NO];
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		
		@try{
		
		
		
		__strong NSURL *audioURL = fixedMImportURLCachedWithURL(self.sourceURL, nil);
		
		NSDictionary* piDict = [NSDictionary dictionary];
		if([self.sourceURL isFileURL]) {
			piDict = fileTagsAtURL(audioURL);
		}
		
		if(self.sourceURL) {
			NSMutableArray* arrayURLHistoryMut = [[[NSUserDefaults standardUserDefaults] objectForKey:@"MImport-allHistoryURLs"]?:@[] mutableCopy];
			NSString* urlSourceSt = [self.sourceURL absoluteString];
			[arrayURLHistoryMut removeObject:urlSourceSt];
			[arrayURLHistoryMut insertObject:urlSourceSt atIndex:0];
			[[NSUserDefaults standardUserDefaults] setObject:arrayURLHistoryMut forKey:@"MImport-allHistoryURLs"];
			[[NSUserDefaults standardUserDefaults] synchronize];
		}
		
		NSMutableDictionary* metaDataParse = [NSMutableDictionary dictionary];
		NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:AVAssetReferenceRestrictionForbidNone], AVURLAssetReferenceRestrictionsKey, nil];
		AVAsset *asset = [AVURLAsset URLAssetWithURL:audioURL options:options];
		for (NSString *format in [asset availableMetadataFormats]) {
			for (AVMetadataItem *item in [asset metadataForFormat:format]) {
				if ([[item commonKey] isEqualToString:kTitle]) {
					metaDataParse[kTitle] = [item value];
				}
				if ([[item commonKey] isEqualToString:kArtist]) {
					metaDataParse[kArtist] = [item value];
				}
				if ([[item commonKey] isEqualToString:@"albumName"]) {
					metaDataParse[@"albumName"] = [item value];
				}
				if ([[item commonKey] isEqualToString:kArtwork]) {
					if ([[item value] isKindOfClass:[NSDictionary class]]) {
						metaDataParse[kArtwork] = ((NSDictionary*)[item value])[@"data"];
					} else {
						metaDataParse[kArtwork] = [item value];
					}
				}
			}
		}
		
		
		NSData* imageData = [metaDataParse objectForKey:kArtwork];
		
		if(!imageData&&[self.sourceURL isFileURL]) {
			NSString* extF = [[[[self.sourceURL path] lastPathComponent]?:@"" pathExtension]?:@"" lowercaseString];
			
			NSString*artworkPath = [self.sourceURL path];
			if(extF.length>0) {
				artworkPath = [artworkPath stringByDeletingPathExtension];
			}
			artworkPath = [artworkPath stringByAppendingPathExtension:@"jpeg"];
	
			NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:fixedMImportURLCachedWithURL([NSURL fileURLWithPath:[[artworkPath stringByDeletingPathExtension] stringByAppendingPathExtension:@"jpeg"]], nil)];
			request.cachePolicy = NSURLRequestReloadIgnoringLocalAndRemoteCacheData;
			imageData = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
			if(imageData) {
				if([imageData length] == 0) {
					imageData = nil;
				}
			}
			if(!imageData) {
				request = [NSMutableURLRequest requestWithURL:fixedMImportURLCachedWithURL([NSURL fileURLWithPath:[[artworkPath stringByDeletingPathExtension] stringByAppendingPathExtension:@"jpg"]], nil)];
				request.cachePolicy = NSURLRequestReloadIgnoringLocalAndRemoteCacheData;
				imageData = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
			}
			if(imageData) {
				if([imageData length] == 0) {
					imageData = nil;
				}
			}
			if(!imageData) {
				request = [NSMutableURLRequest requestWithURL:fixedMImportURLCachedWithURL([NSURL fileURLWithPath:[[artworkPath stringByDeletingPathExtension] stringByAppendingPathExtension:@"png"]], nil)];
				request.cachePolicy = NSURLRequestReloadIgnoringLocalAndRemoteCacheData;
				imageData = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
			}
			if(imageData) {
				if([imageData length] == 0) {
					imageData = nil;
				}
			}
		}
		
		NSString *title, *album, *artist, *genre, *composer;
		title     = [metaDataParse objectForKey:kTitle]?:[piDict objectForKey:kTitle]?:[self fileName]?:@"Unknown Title";
		album     = [metaDataParse objectForKey:@"albumName"]?:[piDict objectForKey:kAlbum]?:@"Unknown Album";
		artist    = [metaDataParse objectForKey:kArtist]?:[piDict objectForKey:kArtist]?:@"Unknown Artist";
		genre     = [piDict objectForKey:kGenre]?:@"";
		composer  = [piDict objectForKey:kComposer]?:@"";
		
		NSDateComponents *components = [[NSCalendar currentCalendar] components:NSCalendarUnitYear fromDate:[NSDate date]];
		int year = (int)[components year];
		int trackNumber = 1;
		int trackCount = 1;
		int isExplicit = 0;
		int durationSecond = 0;
		long long fileSizeNumber = 0;
		
		fileSizeNumber = [[piDict objectForKey:kFileSize]?:@(0) longLongValue];
		//if(fileSizeNumber == 0) {
		//	@try {
		//		for(AVAssetTrack* trk in asset.tracks) {
		//			fileSizeNumber += trk.totalSampleDataLength;
		//		}
		//	}@catch(NSException*e) {
		//	}
		//}
		
		durationSecond = [[piDict objectForKey:kDuration]?:@(0) intValue];
		if(durationSecond == 0) {
			durationSecond = CMTimeGetSeconds(asset.duration);
		}
		
		if(id yearID = [piDict objectForKey:kYear]) {
			if(NSString* yearSt = [NSString stringWithFormat:@"%@", yearID]) {
				if([(NSString*)yearSt length] == 4) {
					year = [yearSt intValue]; 
				} else if([(NSString*)yearSt length] > 4) {
					yearSt = [yearSt substringToIndex:4];
					year = [yearSt intValue]; 
				}
			}
		}
		if(id TrackID = [piDict objectForKey:@"track number"]) {
			if([TrackID isKindOfClass:[NSNumber class]]) {
				trackNumber = [TrackID intValue];
			} else if([TrackID isKindOfClass:[NSString class]]) {
				NSArray* itemArr = [TrackID componentsSeparatedByString:@"/"]?:[NSArray array];
				int index = 0;
				for(id sItemNow in itemArr) {
					if(index == 0) {
						trackNumber = [sItemNow intValue];
					} else {
						trackCount = [sItemNow intValue];
					}
					index++;
				}
			}
		}
		
		NSString *ext = [self extSt];
		[self.tags setObject:ext.length>0?ext:[[NSBundle bundleWithPath:@"/System/Library/Frameworks/UIKit.framework"]?:[NSBundle mainBundle] localizedStringForKey:@"Doesn't support the file type" value:@"Doesn't support the file type" table:nil] forKey:@"fileEX"];
		
		
		int kindType = 1;
		if ([ext isEqualToString:@"mp4"] || [ext isEqualToString:@"m4v"] || [ext isEqualToString:@"mov"] || [ext isEqualToString:@"3gp"]) {
			kindType = 2;
		} else if ([ext isEqualToString:@"m4r"]) {
			kindType = 4;
		}
		
		
		self.tags[kFileSize] = @(fileSizeNumber);
		self.tags[kIsFileZip] = [piDict objectForKey:kIsFileZip]?:@NO;
		self.tags[kExt] = ext;
		self.tags[kSearchTitle] = title;
		self.tags[kTitle] = title;
		self.tags[kAlbum] = album;
		self.tags[kArtist] = artist;
		self.tags[kGenre] = genre;
		self.tags[kComposer] = composer;
		self.tags[kYear] = @(year);
		self.tags[kTrackNumber] = @(trackNumber);
		self.tags[kDuration] = @(durationSecond);
		self.tags[kTrackCount] = @(trackCount);
		self.tags[kExplicit] = @(isExplicit);
		self.tags[kKindType] = @(kindType);
		if(imageData != nil) {
			self.tags[kArtwork] = imageData;
		}	
		} @catch (NSException * e) {
		}
		
		dispatch_async(dispatch_get_main_queue(), ^(void) {
			[hud hide];
			[self.view setUserInteractionEnabled:YES];
			[self reloadSpecifiers];
			
			if(receivedURLMImport_autoFetchTags) {
				receivedURLMImport_autoFetchTags = NO;
				[self getInfoNow];
			}
		});
	});
	
	}
	return self;
}
- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
	__strong UIBarButtonItem* kBTClose = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:self action:@selector(closeMImportEdit)];
	kBTClose.tag = 4;	
	if (self.navigationController.navigationBar.backItem == NULL) {
		self.navigationItem.leftBarButtonItem = kBTClose;
	}
}
- (void)closeMImportEdit
{
	receivedURLMImport = nil;
	[self dismissViewControllerAnimated:YES completion:nil];
}
- (id)specifiers
{
	if (!_specifiers) {
		NSMutableArray* specifiers = [NSMutableArray array];
		PSSpecifier* spec;
		
		spec = [PSSpecifier preferenceSpecifierNamed:[[NSBundle bundleWithPath:@"/System/Library/Frameworks/UIKit.framework"]?:[NSBundle mainBundle] localizedStringForKey:@"Info" value:@"Info" table:nil]
		                                      target:self
											  set:Nil
											  get:Nil
                                              detail:Nil
											  cell:PSGroupCell
											  edit:Nil];
		[spec setProperty:[[NSBundle bundleWithPath:@"/System/Library/Frameworks/UIKit.framework"]?:[NSBundle mainBundle] localizedStringForKey:@"Info" value:@"Info" table:nil] forKey:@"label"];
		[specifiers addObject:spec];
		spec = [PSSpecifier preferenceSpecifierNamed:[[NSBundle bundleWithPath:@"/System/Library/Frameworks/UIKit.framework"]?:[NSBundle mainBundle] localizedStringForKey:@"Name" value:@"Name" table:nil]
					      target:self
						 set:NULL
						 get:@selector(fileName)
					      detail:Nil
						cell:PSTitleValueCell
						edit:Nil];
		[specifiers addObject:spec];
		spec = [PSSpecifier preferenceSpecifierNamed:@"Type"
					      target:self
						 set:NULL
						 get:@selector(fileExt)
					      detail:Nil
						cell:PSTitleValueCell
						edit:Nil];
		[specifiers addObject:spec];
		spec = [PSSpecifier preferenceSpecifierNamed:@"Duration"
					      target:self
						 set:NULL
						 get:@selector(timeFormat)
					      detail:Nil
						cell:PSTitleValueCell
						edit:Nil];
		[specifiers addObject:spec];
		spec = [PSSpecifier preferenceSpecifierNamed:@"Size"
					      target:self
						 set:NULL
						 get:@selector(fileSizeFormat)
					      detail:Nil
						cell:PSTitleValueCell
						edit:Nil];
		[specifiers addObject:spec];
		
		spec = [PSSpecifier preferenceSpecifierNamed:@"Source"
					      target:self
						 set:NULL
						 get:@selector(fileLocation)
					      detail:Nil
						cell:PSTitleValueCell
						edit:Nil];
		[specifiers addObject:spec];
		
		spec = [PSSpecifier preferenceSpecifierNamed:@"Action's"
		                                      target:self
											  set:Nil
											  get:Nil
                                              detail:Nil
											  cell:PSGroupCell
											  edit:Nil];
		[specifiers addObject:spec];
		if([self.sourceURL isFileURL]) {
			spec = [PSSpecifier preferenceSpecifierNamed:@"Open Folder File"
                                              target:self
                                                 set:NULL
                                                 get:NULL
                                              detail:Nil
                                                cell:PSLinkCell
                                                edit:Nil];
			spec->action = @selector(openFolder);
			[specifiers addObject:spec];
		}
		if([self.tags[kIsFileZip] boolValue]) {
			spec = [PSSpecifier preferenceSpecifierNamed:@"Extract Here"
                                              target:self
                                                 set:NULL
                                                 get:NULL
                                              detail:Nil
                                                cell:PSLinkCell
                                                edit:Nil];
			spec->action = @selector(extractFile);
			[specifiers addObject:spec];
		} else {
			spec = [PSSpecifier preferenceSpecifierNamed:@"Play Media"
                                              target:self
                                                 set:NULL
                                                 get:NULL
                                              detail:Nil
                                                cell:PSLinkCell
                                                edit:Nil];
			spec->action = @selector(playMedia);
			[specifiers addObject:spec];
			
			if([self.sourceURL isFileURL]) {
				if(self.showConvertTool) {
					spec = [PSSpecifier preferenceSpecifierNamed:@"Convert Media to ... (Online)"
														target:self
														set:Nil
														get:Nil
														detail:Nil
														cell:PSGroupCell
														edit:Nil];
					[spec setProperty:@"Tags" forKey:@"label"];
					[specifiers addObject:spec];
					
					spec = [PSSpecifier preferenceSpecifierNamed:@"Media Type"
														target:self
															set:@selector(setPreferenceValue:specifier:)
															get:@selector(readPreferenceValue:)
														detail:Nil
															cell:PSSegmentCell
															edit:Nil];
					NSArray* types = @[@"Audio", @"Video"];
					[spec setValues:types titles:types];
					[spec setProperty:@"convMediaType" forKey:@"key"];
					[spec setProperty:@YES forKey:@"reload"];
					[specifiers addObject:spec];
					
					if(self.tags[@"convMediaType"]!=nil) {
						spec = [PSSpecifier preferenceSpecifierNamed:@"Type"
															target:self
																set:@selector(setPreferenceValue:specifier:)
																get:@selector(readPreferenceValue:)
															detail:Nil
																cell:PSSegmentCell
																edit:Nil];
						NSArray* formats = @[
							@"mp3", 
							@"wav", 
							@"wma", 
							@"ogg",
							@"aac",
							@"au",
							@"flac",
							@"m4a",
							@"mka",
							@"aiff", 
							@"opus",
							@"ra", 
							@"amr",
						];
						if([self.tags[@"convMediaType"]?:@"Audio" isEqualToString:@"Video"]) {
							formats = @[
								@"mp4", 
								@"avi", 
								@"mpg", 
								@"mkv",
								@"wmv",
								@"m2ts",
								@"webm",
								@"flv",
								@"mov",
								@"m4v", 
								@"rm",
								@"vob", 
								@"ogv",
								@"swf",
								@"gif",
							];
						}
						[spec setValues:formats titles:formats];
						[spec setProperty:@"convType" forKey:@"key"];
						[spec setProperty:@YES forKey:@"reload"];
						[specifiers addObject:spec];
						
						if(self.tags[@"convType"] != nil) {
							spec = [PSSpecifier preferenceSpecifierNamed:[NSString stringWithFormat:@"Convert to format \"%@\" Now !", [self.tags[@"convType"] uppercaseString]]
												target:self
													set:NULL
													get:NULL
												detail:Nil
													cell:PSLinkCell
													edit:Nil];
							spec->action = @selector(convertMediaNow);
							[specifiers addObject:spec];
						}
					}
				} else {
					spec = [PSSpecifier preferenceSpecifierNamed:@"Convert Media to ..."
                                              target:self
                                                 set:NULL
                                                 get:NULL
                                              detail:Nil
                                                cell:PSLinkCell
                                                edit:Nil];
					spec->action = @selector(showConvertMedia);
					[specifiers addObject:spec];
				}
			}
		}
		
		if([self extSt].length == 0) {
			spec = [PSSpecifier preferenceSpecifierNamed:@"Input File Extension"
		                                      target:self
											  set:Nil
											  get:Nil
                                              detail:Nil
											  cell:PSGroupCell
											  edit:Nil];
			[spec setProperty:@"Input File Extension" forKey:@"label"];
			[spec setProperty:@"You need input file extension before import." forKey:@"footerText"];
			[specifiers addObject:spec];
			spec = [PSSpecifier preferenceSpecifierNamed:@"Extension:"
                                              target:self
											  set:@selector(setPreferenceValue:specifier:)
											  get:@selector(readPreferenceValue:)
                                              detail:Nil
											  cell:PSEditTextCell
											  edit:Nil];
			[spec setProperty:kExt forKey:@"key"];
			[specifiers addObject:spec];
		}
		
		spec = [PSSpecifier preferenceSpecifierNamed:@"Search Tags Online"
		                                      target:self
											  set:Nil
											  get:Nil
                                              detail:Nil
											  cell:PSGroupCell
											  edit:Nil];
		[spec setProperty:@"Search Tags Online" forKey:@"label"];
		[specifiers addObject:spec];
		spec = [PSSpecifier preferenceSpecifierNamed:[[NSBundle bundleWithPath:@"/System/Library/Frameworks/UIKit.framework"]?:[NSBundle mainBundle] localizedStringForKey:@"Search" value:@"Search" table:nil]
                                              target:self
											  set:@selector(setPreferenceValue:specifier:)
											  get:@selector(readPreferenceValue:)
                                              detail:Nil
											  cell:PSEditTextCell
											  edit:Nil];
		[spec setProperty:kSearchTitle forKey:@"key"];
        [specifiers addObject:spec];
		spec = [PSSpecifier preferenceSpecifierNamed:@"Fetch Tags Now"
                                              target:self
                                                 set:NULL
                                                 get:NULL
                                              detail:Nil
                                                cell:PSLinkCell
                                                edit:Nil];
		spec->action = @selector(getInfoNow);
		[spec setProperty:[NSNumber numberWithBool:TRUE] forKey:@"hasIcon"];
		[spec setProperty:kIconMimportGet() forKey:@"iconImage"];
        [specifiers addObject:spec];
		
		/*spec = [PSSpecifier emptyGroupSpecifier];
        [specifiers addObject:spec];
		
		spec = [PSSpecifier preferenceSpecifierNamed:@"Import Now"
                                              target:self
                                                 set:NULL
                                                 get:NULL
                                              detail:Nil
                                                cell:PSLinkCell//PSButtonCell
                                                edit:Nil];
        spec->action = @selector(importFileNow);
        //[spec setProperty:NSClassFromString(@"SSTintedCell") forKey:@"cellClass"];
        [specifiers addObject:spec];*/
		
		spec = [PSSpecifier preferenceSpecifierNamed:@"Tags"
		                                      target:self
											  set:Nil
											  get:Nil
                                              detail:Nil
											  cell:PSGroupCell
											  edit:Nil];
		[spec setProperty:@"Tags" forKey:@"label"];
		[specifiers addObject:spec];
		
		spec = [PSSpecifier preferenceSpecifierNamed:@"Type"
											  target:self
												 set:@selector(setPreferenceValue:specifier:)
												 get:@selector(readPreferenceValue:)
											  detail:Nil
												cell:PSSegmentCell
												edit:Nil];
		NSString *extensionType = [self fileExt];
		if ([extensionType isEqualToString:@"m4a"] || [extensionType isEqualToString:@"m4r"]) {
			[spec setValues:@[@(1), @(2), @(3), @(4)] titles:@[
			[[NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/FuseUI.framework"]?:[NSBundle mainBundle] localizedStringForKey:@"MUSIC" value:@"Song" table:@"FuseUI"],
			@"Video",
			@"TV episode",
			@"Ringtone",
			]];
		} else {
			[spec setValues:@[@(1), @(2), @(3)] titles:@[
			[[NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/FuseUI.framework"]?:[NSBundle mainBundle] localizedStringForKey:@"MUSIC" value:@"Song" table:@"FuseUI"],
			@"Video",
			@"TV episode",
			]];
		}
		[spec setProperty:kKindType forKey:@"key"];
		[specifiers addObject:spec];
		
		spec = [PSSpecifier preferenceSpecifierNamed:@"Artwork"
                                              target:self
                                                 set:NULL
                                                 get:NULL
                                              detail:Nil
                                                cell:PSLinkCell
                                                edit:Nil];
		spec->action = @selector(openLibrary);
		[spec setProperty:[NSNumber numberWithBool:TRUE] forKey:@"hasIcon"];
		NSData* dataArtWork = self.tags[kArtwork];
		if(dataArtWork && dataArtWork.length > 0) {
			[spec setProperty:[UIImage imageWithData:dataArtWork] forKey:@"iconImage"];
		} else {
			[spec setProperty:kIconMimportGet() forKey:@"iconImage"];
		}
        [specifiers addObject:spec];
		
		spec = [PSSpecifier preferenceSpecifierNamed:@"Title"
                                              target:self
											  set:@selector(setPreferenceValue:specifier:)
											  get:@selector(readPreferenceValue:)
                                              detail:Nil
											  cell:PSEditTextCell
											  edit:Nil];
		[spec setProperty:kTitle forKey:@"key"];
        [specifiers addObject:spec];
		
		spec = [PSSpecifier preferenceSpecifierNamed:@"Album"
                                              target:self
											  set:@selector(setPreferenceValue:specifier:)
											  get:@selector(readPreferenceValue:)
                                              detail:Nil
											  cell:PSEditTextCell
											  edit:Nil];
		[spec setProperty:kAlbum forKey:@"key"];
        [specifiers addObject:spec];
		spec = [PSSpecifier preferenceSpecifierNamed:@"Artist"
                                              target:self
											  set:@selector(setPreferenceValue:specifier:)
											  get:@selector(readPreferenceValue:)
                                              detail:Nil
											  cell:PSEditTextCell
											  edit:Nil];
		[spec setProperty:kArtist forKey:@"key"];
        [specifiers addObject:spec];
		spec = [PSSpecifier preferenceSpecifierNamed:@"Genre"
                                              target:self
											  set:@selector(setPreferenceValue:specifier:)
											  get:@selector(readPreferenceValue:)
                                              detail:Nil
											  cell:PSEditTextCell
											  edit:Nil];
		[spec setProperty:kGenre forKey:@"key"];
        [specifiers addObject:spec];
		spec = [PSSpecifier preferenceSpecifierNamed:@"Composer"
                                              target:self
											  set:@selector(setPreferenceValue:specifier:)
											  get:@selector(readPreferenceValue:)
                                              detail:Nil
											  cell:PSEditTextCell
											  edit:Nil];
		[spec setProperty:kComposer forKey:@"key"];
        [specifiers addObject:spec];
		spec = [PSSpecifier preferenceSpecifierNamed:@"Year"
                                              target:self
											  set:@selector(setPreferenceValue:specifier:)
											  get:@selector(readPreferenceValue:)
                                              detail:Nil
											  cell:PSEditTextCell
											  edit:Nil];
		[spec setProperty:kYear forKey:@"key"];
        [specifiers addObject:spec];
		spec = [PSSpecifier preferenceSpecifierNamed:@"Track Number"
                                              target:self
											  set:@selector(setPreferenceValue:specifier:)
											  get:@selector(readPreferenceValue:)
                                              detail:Nil
											  cell:PSEditTextCell
											  edit:Nil];
		[spec setProperty:kTrackNumber forKey:@"key"];
        [specifiers addObject:spec];
		spec = [PSSpecifier preferenceSpecifierNamed:@"Track Total Count"
                                              target:self
											  set:@selector(setPreferenceValue:specifier:)
											  get:@selector(readPreferenceValue:)
                                              detail:Nil
											  cell:PSEditTextCell
											  edit:Nil];
		[spec setProperty:kTrackCount forKey:@"key"];
        [specifiers addObject:spec];		
		spec = [PSSpecifier preferenceSpecifierNamed:@"Lyric"
                                              target:self
											  set:@selector(setPreferenceValue:specifier:)
											  get:@selector(readPreferenceValue:)
                                              detail:Nil
											  cell:PSEditTextCell
											  edit:Nil];
		[spec setProperty:kLyrics forKey:@"key"];
        //[specifiers addObject:spec];
		
		spec = [PSSpecifier preferenceSpecifierNamed:[[NSBundle bundleWithPath:@"/System/Library/Frameworks/MediaPlayer.framework"]?:[NSBundle mainBundle] localizedStringForKey:@"EXPLICIT_CONTENT_NOT_ALLOWED_TITLE" value:@"Explicit" table:@"MediaPlayer"]
                                                  target:self
											         set:@selector(setPreferenceValue:specifier:)
											         get:@selector(readPreferenceValue:)
                                                  detail:Nil
											        cell:PSSwitchCell
											        edit:Nil];
		[spec setProperty:kExplicit forKey:@"key"];
		[specifiers addObject:spec];
		
		if([self.sourceURL isFileURL] && [extensionType isEqualToString:@"mp3"]) {
			spec = [PSSpecifier emptyGroupSpecifier];
			[specifiers addObject:spec];
			[spec setProperty:@"Will Save The Currently Tags To mp3 File Permanently" forKey:@"footerText"];
			spec = [PSSpecifier preferenceSpecifierNamed:@"Overwrite ID3Tags In File Now"
                                              target:self
                                                 set:NULL
                                                 get:NULL
                                              detail:Nil
                                                cell:PSLinkCell
                                                edit:Nil];
			spec->action = @selector(writeID3Tags);
			[specifiers addObject:spec];
		}
		
		spec = [PSSpecifier emptyGroupSpecifier];
		[spec setProperty:[NSString stringWithFormat:@"\n\nSource:\n%@", self.sourceURL] forKey:@"footerText"];
		[specifiers addObject:spec];
		
		spec = [PSSpecifier emptyGroupSpecifier];
        [spec setProperty:getHeaderName() forKey:@"footerText"];
        [specifiers addObject:spec];
		_specifiers = [specifiers copy];
	}
	return _specifiers;
}

- (void)writeID3Tags
{
	NSMutableData* dataMut = [[NSMutableData alloc] init];
	NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:dataMut];
	
	if(self.sourceURL) {
		[archiver encodeObject:[self.sourceURL path] forKey:@"path"];
	}
	
	if(self.tags[kTitle]) {
		[archiver encodeObject:self.tags[kTitle] forKey:kTitle];
	}
	if(self.tags[kArtist]) {
		[archiver encodeObject:self.tags[kArtist] forKey:kArtist];
	}
	if(self.tags[kAlbum]) {
		[archiver encodeObject:self.tags[kAlbum] forKey:kAlbum];
	}
	
	if(self.tags[kGenre]) {
		[archiver encodeObject:self.tags[kGenre] forKey:kGenre];
	}
	if(self.tags[kTrackNumber]) {
		[archiver encodeObject:self.tags[kTrackNumber] forKey:kTrackNumber];
	}
	if(self.tags[kComposer]) {
		[archiver encodeObject:self.tags[kComposer] forKey:kComposer];
	}
	if(self.tags[kYear]) {
		[archiver encodeObject:self.tags[kYear] forKey:kYear];
	}
	
	
	if(self.tags[kArtwork]) {
		[archiver encodeObject:self.tags[kArtwork] forKey:@"artwork"];
	}
	
	[archiver finishEncoding];
	
	BOOL result = NO;
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:kUrlServer]];
	[request setHTTPMethod:@"WID3"];
	[request setTimeoutInterval:3600];
	[request setHTTPBody:dataMut];
	request.cachePolicy = NSURLRequestReloadIgnoringLocalAndRemoteCacheData;
	NSError* error = nil;
	__autoreleasing NSData* data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:&error];
	if(data) {
		NSDictionary *jsonDic = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil]?:@{};
		result = [jsonDic[@"result"]?:@NO boolValue];
		
		dispatch_async(dispatch_get_main_queue(), ^(void) {
			NSString* titleSt = @"MImport";
			NSString* messageSt = (result&&error==nil)?@"ID3 Tags Saved.":error!=nil?[error localizedDescription]:@"Error";
			NSString* okSt = @"OK";
			
			if(%c(UIAlertController) != nil) {
				UIAlertController* alert = [%c(UIAlertController) alertControllerWithTitle:titleSt message:messageSt preferredStyle:UIAlertControllerStyleAlert];
				UIAlertAction* defaultAction = [%c(UIAlertAction) actionWithTitle:okSt style:UIAlertActionStyleDefault handler:nil];
				[alert addAction:defaultAction];
				[topMostController() presentViewController:alert animated:YES completion:nil];
			} else {
				UIAlertView *alert = [[%c(UIAlertView) alloc] initWithTitle:titleSt message:messageSt delegate:nil cancelButtonTitle:okSt otherButtonTitles:nil];
				[alert show];
			}
		});
	}
}

- (void)showConvertMedia
{
	self.showConvertTool = YES;
	[self reloadSpecifiers];
}
- (void)convertMediaNow
{
	NSString* tagetType = self.tags[@"convType"];
	if(!tagetType) {
		return;
	}
	
	if(!self.hud) {
		hud = [[UIProgressHUD alloc] init];
	}
	NSString* path = [self.sourceURL path];
	[hud setText:[NSString stringWithFormat:@"%@ %@", @"Converting", [path lastPathComponent]]];
	[hud showInView:self.view];
	[self.view setUserInteractionEnabled:NO];
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		NSString* newURLSt = nil;
		BOOL success = NO;
		
		@autoreleasepool {
			NSURL* url = [NSURL URLWithString:@"https://s23.aconvert.com/convert/convert-batch3.php"];
			NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:999999.0];
			[request setHTTPMethod:@"POST"];
			
			[request setValue:@"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/81.0.4044.138 Safari/537.36" forHTTPHeaderField: @"User-Agent"];
			[request setValue:@"https://www.aconvert.com" forHTTPHeaderField: @"Origin"];
			[request setValue:@"https://www.aconvert.com/" forHTTPHeaderField: @"Referer"];
			[request setValue:@"same-site" forHTTPHeaderField: @"Sec-Fetch-Site"];
			[request setValue:@"cors" forHTTPHeaderField: @"Sec-Fetch-Mode"];
			[request setValue:@"empty" forHTTPHeaderField: @"Sec-Fetch-Dest"];
			
			NSString *boundary = [@"----WebKitFormBoundaryTKSglKtTqNyZ5tJx" copy];
			
			NSString *kNewLine = [@"\r\n" copy];
			NSString *kContentForm = [@"Content-Disposition: form-data; name=\"%@\"" copy];
			NSString *kboundaryStart = [@"--%@%@" copy];
			NSString *kOctetSream = [@"Content-Type: application/octet-stream" copy];
			
			void(^appendField)(NSMutableData*, NSString*, NSString*)  = ^(NSMutableData* body, NSString* name, NSString* value) {
				[body appendData:[[NSString stringWithFormat:kboundaryStart, boundary, kNewLine] dataUsingEncoding:NSUTF8StringEncoding]];
				[body appendData:[[NSString stringWithFormat:kContentForm, [NSString stringWithFormat:@"%@",name]] dataUsingEncoding:NSUTF8StringEncoding]];
				[body appendData:[kNewLine dataUsingEncoding:NSUTF8StringEncoding]];
				[body appendData:[kNewLine dataUsingEncoding:NSUTF8StringEncoding]];
				[body appendData:[[NSString stringWithFormat:@"%@",value] dataUsingEncoding:NSUTF8StringEncoding]];
				[body appendData:[kNewLine dataUsingEncoding:NSUTF8StringEncoding]];
			};
			
			[request setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary] forHTTPHeaderField: @"Content-Type"];
			
			
			__autoreleasing NSMutableData *body = [NSMutableData data];
			
			[body appendData:[[NSString stringWithFormat:kboundaryStart, boundary, kNewLine] dataUsingEncoding:NSUTF8StringEncoding]];
			[body appendData:[[NSString stringWithFormat:kContentForm, @"file"] dataUsingEncoding:NSUTF8StringEncoding]];
			[body appendData:[[NSString stringWithFormat:@"; filename=\"%@\"", [path lastPathComponent]] dataUsingEncoding:NSUTF8StringEncoding]];
			[body appendData:[kNewLine dataUsingEncoding:NSUTF8StringEncoding]];
			[body appendData:[kOctetSream dataUsingEncoding:NSUTF8StringEncoding]];
			[body appendData:[kNewLine dataUsingEncoding:NSUTF8StringEncoding]];
			[body appendData:[kNewLine dataUsingEncoding:NSUTF8StringEncoding]];
			NSURL *mediaURL = fixedMImportURLCachedWithURL(self.sourceURL, nil);
			__autoreleasing NSData* fileData = [NSData dataWithContentsOfURL:mediaURL];
			[body appendData:fileData];
			[body appendData:[kNewLine dataUsingEncoding:NSUTF8StringEncoding]];
			
			appendField(body, @"targetformat", tagetType);
			appendField(body, @"audiobitratetype", @"0");
			appendField(body, @"customaudiobitrate", @"");
			appendField(body, @"audiosamplingtype", @"0");
			appendField(body, @"customaudiosampling", @"");
			appendField(body, @"code", @"82000");
			appendField(body, @"filelocation", @"local");
			appendField(body, @"oAuthToken", @"");		
			
			[body appendData:[[NSString stringWithFormat:kboundaryStart, boundary, @"--"] dataUsingEncoding:NSUTF8StringEncoding]];
			[body appendData:[kNewLine dataUsingEncoding:NSUTF8StringEncoding]];
			[request setHTTPBody:body];
			
			__autoreleasing NSData *receivedData = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil]?:[NSData data];
			NSDictionary *jsonResp = [NSJSONSerialization JSONObjectWithData:receivedData options:0 error:nil]?:@{};
			
			NSString* file = jsonResp[@"filename"];
			if(file) {
				newURLSt = [[NSString stringWithFormat:@"https://s23.aconvert.com/convert/p3r68-cdx67/%@", file] copy];
				success = YES;
			}
		}
		dispatch_async(dispatch_get_main_queue(), ^(void) {
			[self.view setUserInteractionEnabled:YES];
			[hud hide];
		});
		if(success) {
			dispatch_async(dispatch_get_main_queue(), ^(void) {
				if(newURLSt) {
					MImportEditTagListController *newVC = [[%c(MImportEditTagListController) alloc] initWithURL:[NSURL URLWithString:newURLSt]];
					@try {
						[self.navigationController pushViewController:newVC animated:YES];
					} @catch (NSException * e) {
					}
				}
			});
		}
	});
}
- (void)extractFile
{
	if(!self.hud) {
		hud = [[UIProgressHUD alloc] init];
	}
	NSString* path = [self.sourceURL path];
	[hud setText:[NSString stringWithFormat:@"%@ %@", @"Extracting", [path lastPathComponent]]];
	[hud showInView:self.view];
	[self.view setUserInteractionEnabled:NO];
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		NSString* pathDest = nil;
		BOOL success = fileOperation(fileOperationExtract, path, nil, &pathDest);
		dispatch_async(dispatch_get_main_queue(), ^(void) {
			[self.view setUserInteractionEnabled:YES];
			[hud hide];
		});
		if(success) {
			dispatch_async(dispatch_get_main_queue(), ^(void) {
				if(pathDest) {
					MImportDirBrowserController *dbtvc = [[[MImportDirBrowserController alloc] init] initWithStyle:UITableViewStyleGrouped];
					dbtvc.path = pathDest;
					@try {
						[self.navigationController pushViewController:dbtvc animated:YES];
					} @catch (NSException * e) {
					}
				}
			});
		}
	});
}
- (void)getInfoNow
{
	[self.view endEditing:YES];
	if(!self.hud) {
		hud = [[UIProgressHUD alloc] init];
	}
	[hud setText:@"Fetching..."];
	[hud showInView:self.view];
 	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		@try {
			NSDictionary* responceInfo = getMusicInfo(@{
				kTitle:self.tags[kSearchTitle]?[self.tags[kSearchTitle] isEqualToString:@"Unknown Title"]?@"":self.tags[kSearchTitle]:@"",
				kAlbum:self.tags[kAlbum]?[self.tags[kAlbum] isEqualToString:@"Unknown Album"]?@"":self.tags[kAlbum]:@"",
				kArtist:self.tags[kArtist]?[self.tags[kArtist] isEqualToString:@"Unknown Artist"]?@"":self.tags[kArtist]:@"",
				kDuration:self.tags[kDuration]?:@"",
			});
			//NSLog(@"*** responceInfo: %@", responceInfo);
			
			NSString* artworkURL = nil;
			for(NSString* artKey in @[@"album_coverart_100x100", @"album_coverart_350x350", @"album_coverart_500x500", @"album_coverart_800x800"]) {
				NSString* artURLSt = responceInfo[artKey];
				if(!artURLSt || [artURLSt length] < 2 || [artURLSt rangeOfString:@"nocover.png"].location != NSNotFound) {
					continue;
				}
				artworkURL = artURLSt;
			}
			
			if(artworkURL) {
				NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:artworkURL]];
				request.cachePolicy = NSURLRequestReloadIgnoringLocalAndRemoteCacheData;
				NSError* error = nil;
				__autoreleasing NSData* imageData = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:&error];
				if(imageData && !error) {
					UIImage *image = [UIImage imageWithData:imageData];
					self.tags[kArtwork] = UIImageJPEGRepresentation(image, 1.0);
				}
			}

			if(NSString* track_name = responceInfo[@"track_name"]) {
				if([track_name length] > 0) {
					self.tags[kTitle] = track_name;
				}
			}
			if(NSString* album_name = responceInfo[@"album_name"]) {
				if([album_name length] > 0) {
					self.tags[kAlbum] = album_name;
				}
			}
			if(NSString* artist_name = responceInfo[@"artist_name"]) {
				if([artist_name length] > 0) {
					self.tags[kArtist] = artist_name;
				}
			}
			if(id explicitRes = responceInfo[@"explicit"]) {
				self.tags[kExplicit] = @([explicitRes intValue]);
			}
			if(id Lyric = responceInfo[kLyrics]) {
				self.tags[kLyrics] = Lyric;
			}
			
		} @catch (NSException * e) {
		}
		dispatch_async(dispatch_get_main_queue(), ^(void) {
			[hud hide];
			[self reloadSpecifiers];
		});
	});
}
- (void)openFolder
{
	dispatch_async(dispatch_get_main_queue(), ^(void) {
		MImportDirBrowserController *dbtvc = [[[MImportDirBrowserController alloc] init] initWithStyle:UITableViewStyleGrouped];
		dbtvc.path = [[self.sourceURL path] stringByDeletingLastPathComponent];
		@try {
			[self.navigationController pushViewController:dbtvc animated:YES];
		} @catch (NSException * e) {
		}
	});
}
- (void)playMedia
{
	playFromURLWithViewController(self, self.sourceURL);
}
- (void)openLibrary
{
	UIImagePickerController *imagePickController = [[UIImagePickerController alloc] init];
    imagePickController.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    imagePickController.delegate = (id)self;
    imagePickController.allowsEditing = TRUE;
    [self presentModalViewController:imagePickController animated:YES];
}
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
	if(cell.textLabel.text && [cell.textLabel.text isEqualToString:@"Artwork"]) {
		return YES;
	}
    return NO;
}
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if(editingStyle == UITableViewCellEditingStyleDelete) {
        UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
		if(cell.textLabel.text && [cell.textLabel.text isEqualToString:@"Artwork"]) {
			self.tags[kArtwork] = [NSData data];
			[self reloadSpecifiers];
		}
    }
}
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    UIImage *image = info[UIImagePickerControllerEditedImage];
	self.tags[kArtwork] = UIImageJPEGRepresentation(image, 1.0);
    [self dismissModalViewControllerAnimated:YES];
	[self reloadSpecifiers];
}
- (void)setRightButton
{
	__strong UIBarButtonItem* kBTClose = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:self action:@selector(closeMImportEdit)];
	__strong UIBarButtonItem* kBTRight = [[UIBarButtonItem alloc] initWithTitle:[[NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/PhotoLibrary.framework"]?:[NSBundle mainBundle] localizedStringForKey:@"IMPORT" value:@"Import" table:@"PhotoLibrary"] style:UIBarButtonItemStylePlain target:self action:@selector(importFileNow)];
	UIBarButtonItem* kBTShare = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(shareAction)];
	kBTRight.tag = 4;
	self.navigationItem.rightBarButtonItems = @[kBTClose, kBTRight, kBTShare];	
}
- (void)shareAction
{
	if(!self.hud) {
		hud = [[UIProgressHUD alloc] init];
	}
	[hud setText:[NSString stringWithFormat:@"Loading..."]];
	[hud showInView:self.view];
	[self.view setUserInteractionEnabled:NO];
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[self.sourceURL lastPathComponent]];
		@autoreleasepool {
			NSURL *mediaURL = fixedMImportURLCachedWithURL(self.sourceURL, nil);
			NSData* fileData = [NSData dataWithContentsOfURL:mediaURL];
			[fileData writeToFile:filePath atomically:YES];
		}
		dispatch_async(dispatch_get_main_queue(), ^(void) {
			[self.view setUserInteractionEnabled:YES];
			[hud hide];
			
			UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[[NSURL fileURLWithPath:filePath]] applicationActivities:nil];
			[self presentViewController:activityViewController animated:YES completion:nil];
		});
	});
}
- (void)viewDidLoad
{
	[super viewDidLoad];
	self.title = [[NSBundle bundleWithPath:@"/System/Library/Frameworks/UIKit.framework"]?:[NSBundle mainBundle] localizedStringForKey:@"Edit" value:@"Edit" table:nil];
	[self setRightButton];
	__strong UIRefreshControl *refreshControl;
	if(!refreshControl) {
		refreshControl = [[UIRefreshControl alloc] init];
		[refreshControl addTarget:self action:@selector(refresh:) forControlEvents:UIControlEventValueChanged];
		refreshControl.tag = 8654;
	}	
	if(UITableView* tableV = (UITableView *)object_getIvar(self, class_getInstanceVariable([self class], "_table"))) {
		if(UIView* rem = [tableV viewWithTag:8654]) {
			[rem removeFromSuperview];
		}
		[tableV addSubview:refreshControl];
	}
}
- (void)viewWillAppear:(BOOL)arg1
{
	[super viewWillAppear:arg1];
	[[MImportTapMenu sharedInstance] _deviceOrientationDidChange];
}
- (void)refresh:(UIRefreshControl *)refresh
{
	startServer();
	[self reloadSpecifiers];
	[refresh endRefreshing];
}
- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier
{
	self.tags[[specifier identifier]] = value;
	if([[specifier properties][@"reload"]?:@NO boolValue]) {
		[self reloadSpecifiers];
	}
}
- (id)readPreferenceValue:(PSSpecifier*)specifier
{
	return self.tags[[specifier identifier]]?:[specifier properties][@"default"];
}
- (void)_returnKeyPressed:(id)arg1
{
	[super _returnKeyPressed:arg1];
	[self.view endEditing:YES];
}
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}
@end


@implementation CellInfoApp
@synthesize sourceURL, icon, bundleId, name, info;
@end

@implementation MImportAppsController
@synthesize allUserApps = _allUserApps, allSystemApps = _allSystemApps, allSharedGroup = _allSharedGroup, hud;
+ (id)shared
{
	static __strong MImportAppsController* MImportAppsControllerC;
	if(!MImportAppsControllerC) {
		MImportAppsControllerC = [[[self class] alloc] initWithStyle:UITableViewStyleGrouped];
	}
	return MImportAppsControllerC;
}
- (id)init
{
	self = [super init];
	if(self) {
		self.allUserApps = [NSArray array];
		self.allSystemApps = [NSArray array];
		self.allSharedGroup = [NSArray array];
	}
	return self;
}
- (void)Refresh
{
	if(!self.hud) {
		hud = [[UIProgressHUD alloc] init];
	}
	[hud setText:@"Loading Apps..."];
	[hud showInView:self.view];
	[self.view setUserInteractionEnabled:NO];
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		NSMutableArray* appUserPx = [NSMutableArray array];
		NSMutableArray* appSystemPx = [NSMutableArray array];
		NSMutableArray* sharedGroupArr = [NSMutableArray array];
		NSMutableDictionary* sharedGroup = [NSMutableDictionary dictionary];
		LSApplicationWorkspace* lsWk = [%c(LSApplicationWorkspace) defaultWorkspace];
		for(LSApplicationProxy* appNow in [lsWk allInstalledApplications]) {
			NSURL* dataURL = [appNow containerURL];
			if(dataURL&&[dataURL absoluteString].length>0) {
				CellInfoApp* CellAppNow = [[CellInfoApp alloc] init];
				CellAppNow.name = [appNow localizedName];
				CellAppNow.sourceURL = dataURL;
				CellAppNow.bundleId = appNow.applicationIdentifier;
				CellAppNow.icon = [UIImage _applicationIconImageForBundleIdentifier:appNow.applicationIdentifier format:0 scale:[UIScreen mainScreen].scale];
				[([[appNow applicationType]?:@"" isEqualToString:@"System"])?appSystemPx:appUserPx addObject:CellAppNow];
			}
			if([appNow respondsToSelector:@selector(groupContainerURLs)]) {
				NSDictionary* sharedGroupNow = [appNow groupContainerURLs];
				for(NSString* groupIdNow in [sharedGroupNow allKeys]) {
					sharedGroup[groupIdNow] = sharedGroupNow[groupIdNow];
				}
			}
		}
		for(NSString* groupIdNow in [sharedGroup allKeys]) {
			CellInfoApp* CellAppNow = [[CellInfoApp alloc] init];
			CellAppNow.name = groupIdNow;
			CellAppNow.sourceURL = sharedGroup[groupIdNow];
			[sharedGroupArr addObject:CellAppNow];
		}
		[appSystemPx sortUsingComparator:^NSComparisonResult(CellInfoApp* obj1, CellInfoApp* obj2) {
			NSString* name1 = [obj1 name]?:@"";
			NSString* name2 = [obj2 name]?:@"";
			return [name1 compare:name2];
		}];
		[appUserPx sortUsingComparator:^NSComparisonResult(CellInfoApp* obj1, CellInfoApp* obj2) {
			NSString* name1 = [obj1 name]?:@"";
			NSString* name2 = [obj2 name]?:@"";
			return [name1 compare:name2];
		}];
		
		self.allSystemApps = [appSystemPx copy];
		self.allUserApps = [appUserPx copy];
		self.allSharedGroup = [sharedGroupArr copy];
		dispatch_async(dispatch_get_main_queue(), ^(void) {
			[hud hide];
			[self.view setUserInteractionEnabled:YES];
			[self.tableView reloadData];
		});	
	});
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
    if (cell == nil) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"Cell"];
    }
	
	CellInfoApp* appRow = indexPath.section==0?self.allUserApps[indexPath.row]:indexPath.section==1?self.allSystemApps[indexPath.row]:self.allSharedGroup[indexPath.row];
	cell.textLabel.text = appRow.name;
	cell.detailTextLabel.text = appRow.info;
	cell.imageView.image = appRow.icon;
	
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}
- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	CellInfoApp* appRow = indexPath.section==0?self.allUserApps[indexPath.row]:indexPath.section==1?self.allSystemApps[indexPath.row]:self.allSharedGroup[indexPath.row];
	MImportDirBrowserController *dbtvc = [[[MImportDirBrowserController alloc] init] initWithStyle:self.tableView.style];
	dbtvc.path = [[appRow sourceURL] path];
	@try {
		[self.navigationController pushViewController:dbtvc animated:YES];
	} @catch (NSException * e) {
	}
	return nil;
}
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
	//[self Refresh];
	[[MImportTapMenu sharedInstance] _deviceOrientationDidChange];
}
- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
	__strong UIBarButtonItem* kBTClose = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:self action:@selector(closeMImport)];
	kBTClose.tag = 4;	
	if(self.navigationController.navigationBar.backItem == NULL) {
		self.navigationItem.leftBarButtonItem = kBTClose;
	}
}
- (void)setRightButton
{
	__strong UIBarButtonItem* kBTClose = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:self action:@selector(closeMImport)];
	__strong UIBarButtonItem *noButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"•••" style:UIBarButtonItemStylePlain target:self action:@selector(showOptions)];
	noButtonItem.tag = 4;
	self.navigationItem.rightBarButtonItems = @[kBTClose, noButtonItem];	
}
- (void)showOptions
{
	NSString* importSt = @"Import From...";
	NSString* cancelSt = [[NSBundle bundleWithPath:@"/System/Library/Frameworks/UIKit.framework"]?:[NSBundle mainBundle] localizedStringForKey:@"Cancel" value:@"Cancel" table:nil];
	
	if(%c(UIAlertController) != nil) {
		UIAlertController *alert = [%c(UIAlertController) alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
		actionShetModel* model = [[actionShetModel alloc] init];
		[model setContext:@"more"];	
		UIAlertAction* actionImport = [%c(UIAlertAction) actionWithTitle:importSt style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
			model.buttonName = importSt;
			[self actionSheet:(UIActionSheet *)model clickedButtonAtIndex:1];
		}];
		[alert addAction:actionImport];
		UIAlertAction *cancel = [%c(UIAlertAction) actionWithTitle:cancelSt style:UIAlertActionStyleCancel handler:nil];
		[alert addAction:cancel];
		[self presentViewController:alert animated:YES completion:nil];
	} else {
		UIActionSheet *popup = [[%c(UIActionSheet) alloc] initWithTitle:nil delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
		[popup setContext:@"more"];	
		[popup addButtonWithTitle:importSt];
		[popup addButtonWithTitle:cancelSt];
		[popup setCancelButtonIndex:[popup numberOfButtons] - 1];
		if (isDeviceIPad) {
			[popup showFromBarButtonItem:[[self navigationItem] rightBarButtonItem] animated:YES];
		} else {
			[popup showInView:self.view];
		}
	}
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	self.title = @"Applications";
	UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
	[refreshControl addTarget:self action:@selector(refreshView:) forControlEvents:UIControlEventValueChanged];
	[self.tableView addSubview:refreshControl];
	[self Refresh];
}
- (NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	if(section==0) {
		return @"User Documents";
	} else if(section==1) {
		return @"System Documents";
	} else if(section==2) {
		return @"Shared Group Documents";
	}
	return nil;
}
- (void)loadView
{
	[super loadView];	
	[self setRightButton];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 3;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [section==0?self.allUserApps:section==1?self.allSystemApps:self.allSharedGroup count];
}
- (void)closeMImport
{
	[self dismissViewControllerAnimated:YES completion:nil];
}
- (void)refreshView:(UIRefreshControl *)refresh
{
	[self Refresh];
	[refresh endRefreshing];
}
- (void)actionSheet:(UIActionSheet *)alert clickedButtonAtIndex:(NSInteger)button 
{
	NSString* contextAlert = [alert context];
	NSString* buttonTitle = [[alert buttonTitleAtIndex:button] copy];
	
	if (button == [alert cancelButtonIndex]) {
		return;
	}
	if(contextAlert&&[contextAlert isEqualToString:@"more"]) {
		
		if ([buttonTitle isEqualToString:@"Import From..."]) {
			openImportFrom(self);
		}
		
		return;
	}
}
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
	if(section == [self numberOfSectionsInTableView:tableView]-1) {
		return getHeaderName();
	}
	return [super tableView:tableView titleForFooterInSection:section];
}
@end


@implementation MImportHistoryController
@synthesize allHistoryURLs = _allHistoryURLs;
+ (id)shared
{
	static __strong MImportHistoryController* MImportHistoryControllerC;
	if(!MImportHistoryControllerC) {
		MImportHistoryControllerC = [[[self class] alloc] initWithStyle:UITableViewStyleGrouped];
	}
	return MImportHistoryControllerC;
}
- (id)init
{
	self = [super init];
	if(self) {
		self.allHistoryURLs = [NSArray array];
	}
	return self;
}
- (void)Refresh
{
	self.allHistoryURLs = [[[NSUserDefaults standardUserDefaults] objectForKey:@"MImport-allHistoryURLs"]?:@[] copy];
	[self.tableView reloadData];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
		cell.textLabel.lineBreakMode = NSLineBreakByWordWrapping;
		cell.textLabel.numberOfLines = 0;
		cell.textLabel.font = [UIFont systemFontOfSize:10.0];	
    }
	
	cell.textLabel.text = nil;
	cell.detailTextLabel.text = nil;
	cell.imageView.image = nil;
	
	if(indexPath.section == 0) {
		cell.textLabel.text = @"Clean All";
	} else if(indexPath.section == 1) {
		NSString* indexURLSt = self.allHistoryURLs[indexPath.row];
		cell.textLabel.text = indexURLSt;
		cell.detailTextLabel.text = nil;
		cell.imageView.image = nil;
	}
	
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}
- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if(indexPath.section == 0) {
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"MImport-allHistoryURLs"];
		[[NSUserDefaults standardUserDefaults] synchronize];
		[self Refresh];
	} else if(indexPath.section == 1) {
		@try {
			[self.navigationController pushViewController:[[%c(MImportEditTagListController) alloc] initWithURL:[NSURL URLWithString:self.allHistoryURLs[indexPath.row]]] animated:YES];
		} @catch (NSException * e) {
		}
	}
	return nil;
}
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
	[[MImportTapMenu sharedInstance] _deviceOrientationDidChange];
	[self Refresh];
	
}
- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
	__strong UIBarButtonItem* kBTClose = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:self action:@selector(closeMImport)];
	kBTClose.tag = 4;	
	if(self.navigationController.navigationBar.backItem == NULL) {
		self.navigationItem.leftBarButtonItem = kBTClose;
	}
}
- (void)setRightButton
{
	__strong UIBarButtonItem* kBTClose = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:self action:@selector(closeMImport)];
	__strong UIBarButtonItem *noButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"•••" style:UIBarButtonItemStylePlain target:self action:@selector(showOptions)];
	noButtonItem.tag = 4;
	self.navigationItem.rightBarButtonItems = @[kBTClose, noButtonItem];	
}
- (void)showOptions
{
	NSString* importSt = @"Import From...";
	NSString* cancelSt = [[NSBundle bundleWithPath:@"/System/Library/Frameworks/UIKit.framework"]?:[NSBundle mainBundle] localizedStringForKey:@"Cancel" value:@"Cancel" table:nil];
	
	if(%c(UIAlertController) != nil) {
		UIAlertController *alert = [%c(UIAlertController) alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
		actionShetModel* model = [[actionShetModel alloc] init];
		[model setContext:@"more"];	
		UIAlertAction* actionImport = [%c(UIAlertAction) actionWithTitle:importSt style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
			model.buttonName = importSt;
			[self actionSheet:(UIActionSheet *)model clickedButtonAtIndex:1];
		}];
		[alert addAction:actionImport];
		UIAlertAction *cancel = [%c(UIAlertAction) actionWithTitle:cancelSt style:UIAlertActionStyleCancel handler:nil];
		[alert addAction:cancel];
		[self presentViewController:alert animated:YES completion:nil];
	} else {
		UIActionSheet *popup = [[%c(UIActionSheet) alloc] initWithTitle:nil delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
		[popup setContext:@"more"];	
		[popup addButtonWithTitle:importSt];
		[popup addButtonWithTitle:cancelSt];
		[popup setCancelButtonIndex:[popup numberOfButtons] - 1];
		if (isDeviceIPad) {
			[popup showFromBarButtonItem:[[self navigationItem] rightBarButtonItem] animated:YES];
		} else {
			[popup showInView:self.view];
		}
	}
}
- (void)viewDidLoad
{
	[super viewDidLoad];
	self.title = @"Recent";
	UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
	[refreshControl addTarget:self action:@selector(refreshView:) forControlEvents:UIControlEventValueChanged];
	[self.tableView addSubview:refreshControl];
	[self Refresh];
}
- (NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	if(section==1) {
		return @"Last's Access";
	}
	return nil;
}
- (void)loadView
{
	[super loadView];	
	[self setRightButton];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if(section == 0) {
		return ([self.allHistoryURLs count]>0)?1:0;
	}
    return [self.allHistoryURLs count];
}
- (void)closeMImport
{
	[self dismissViewControllerAnimated:YES completion:nil];
}
- (void)refreshView:(UIRefreshControl *)refresh
{
	[self Refresh];
	[refresh endRefreshing];
}
- (void)actionSheet:(UIActionSheet *)alert clickedButtonAtIndex:(NSInteger)button 
{
	NSString* contextAlert = [alert context];
	NSString* buttonTitle = [[alert buttonTitleAtIndex:button] copy];
	
	if (button == [alert cancelButtonIndex]) {
		return;
	}
	if(contextAlert&&[contextAlert isEqualToString:@"more"]) {
		
		if ([buttonTitle isEqualToString:@"Import From..."]) {
			openImportFrom(self);
		}
		
		return;
	}
}
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath 
{
	return	YES;
}
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	@try {
		if(indexPath.section == 1) {
			NSMutableArray* arrayURLHistoryMut = [[[NSUserDefaults standardUserDefaults] objectForKey:@"MImport-allHistoryURLs"]?:@[] mutableCopy];
			[arrayURLHistoryMut removeObject:self.allHistoryURLs[indexPath.row]];
			[[NSUserDefaults standardUserDefaults] setObject:arrayURLHistoryMut forKey:@"MImport-allHistoryURLs"];
			[[NSUserDefaults standardUserDefaults] synchronize];
			[self Refresh];
			return;
		}
	} @catch (NSException * e) {
	}
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if(indexPath.section == 1) {
		NSString *cellText = self.allHistoryURLs[indexPath.row];
		UIFont *cellFont = [UIFont systemFontOfSize:10.0];
		NSAttributedString *attributedText = [[NSAttributedString alloc] initWithString:cellText attributes:@{NSFontAttributeName: cellFont}];
		CGRect rect = [attributedText boundingRectWithSize:CGSizeMake(tableView.bounds.size.width, CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin context:nil];
		return rect.size.height + 20;
	}
	return [super tableView:tableView heightForRowAtIndexPath:indexPath];
}
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
	if(section == [self numberOfSectionsInTableView:tableView]-1) {
		return getHeaderName();
	}
	return [super tableView:tableView titleForFooterInSection:section];
}
@end


@implementation MImportFavoriteController
@synthesize allFavURLs = _allFavURLs;
+ (id)shared
{
	static __strong MImportFavoriteController* MImportFavoriteControllerC;
	if(!MImportFavoriteControllerC) {
		MImportFavoriteControllerC = [[[self class] alloc] initWithStyle:UITableViewStyleGrouped];
	}
	return MImportFavoriteControllerC;
}
- (id)init
{
	self = [super init];
	if(self) {
		self.allFavURLs = [NSDictionary dictionary];
	}
	return self;
}
- (void)Refresh
{
	if([[NSUserDefaults standardUserDefaults] objectForKey:@"MImport-allFavURLs"] == nil) {
		[[NSUserDefaults standardUserDefaults] setObject:@{
			@"/var/mobile/Downloads": @{@"name": @"Downloads", @"path": @"/var/mobile/Downloads"},
			@"/var/mobile/Documents": @{@"name": @"Documents", @"path": @"/var/mobile/Documents"},
			@"/var/mobile/Media": @{@"name": @"Media", @"path": @"/var/mobile/Media"},
			@"/var/root": @{@"name": @"root", @"path": @"/var/root"},
		} forKey:@"MImport-allFavURLs"];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
	self.allFavURLs = [[[NSUserDefaults standardUserDefaults] objectForKey:@"MImport-allFavURLs"] copy];
	[self.tableView reloadData];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];	
    }
	
	cell.textLabel.text = nil;
	cell.detailTextLabel.text = nil;
	cell.imageView.image = nil;
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	
	if(indexPath.section == 0) {
		NSDictionary* rowFav = self.allFavURLs[[self.allFavURLs allKeys][indexPath.row]];
		cell.textLabel.text = rowFav[@"name"];
		cell.detailTextLabel.text = rowFav[@"path"];
		cell.imageView.image = kImageDirGet();
	}
	
    return cell;
}
- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if(indexPath.section == 0) {
		@try {
			NSDictionary* rowFav = self.allFavURLs[[self.allFavURLs allKeys][indexPath.row]];			
			MImportDirBrowserController *dbtvc = [[[MImportDirBrowserController alloc] init] initWithStyle:self.tableView.style];
			dbtvc.path = rowFav[@"path"];
			[self.navigationController pushViewController:dbtvc animated:YES];
		} @catch (NSException * e) {
		}
	}
	return nil;
}
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
	[[MImportTapMenu sharedInstance] _deviceOrientationDidChange];
	[self Refresh];
}
- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
	__strong UIBarButtonItem* kBTClose = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:self action:@selector(closeMImport)];
	kBTClose.tag = 4;	
	if(self.navigationController.navigationBar.backItem == NULL) {
		self.navigationItem.leftBarButtonItem = kBTClose;
	}
}
- (void)setRightButton
{
	__strong UIBarButtonItem* kBTClose = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:self action:@selector(closeMImport)];
	__strong UIBarButtonItem *noButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"•••" style:UIBarButtonItemStylePlain target:self action:@selector(showOptions)];
	noButtonItem.tag = 4;
	self.navigationItem.rightBarButtonItems = @[kBTClose, noButtonItem];	
}
- (void)showOptions
{
	NSString* importSt = @"Import From...";
	NSString* cancelSt = [[NSBundle bundleWithPath:@"/System/Library/Frameworks/UIKit.framework"]?:[NSBundle mainBundle] localizedStringForKey:@"Cancel" value:@"Cancel" table:nil];
	
	if(%c(UIAlertController) != nil) {
		UIAlertController *alert = [%c(UIAlertController) alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
		actionShetModel* model = [[actionShetModel alloc] init];
		[model setContext:@"more"];	
		UIAlertAction* actionImport = [%c(UIAlertAction) actionWithTitle:importSt style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
			model.buttonName = importSt;
			[self actionSheet:(UIActionSheet *)model clickedButtonAtIndex:1];
		}];
		[alert addAction:actionImport];
		UIAlertAction *cancel = [%c(UIAlertAction) actionWithTitle:cancelSt style:UIAlertActionStyleCancel handler:nil];
		[alert addAction:cancel];
		[self presentViewController:alert animated:YES completion:nil];
	} else {
		UIActionSheet *popup = [[%c(UIActionSheet) alloc] initWithTitle:nil delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
		[popup setContext:@"more"];	
		[popup addButtonWithTitle:importSt];
		[popup addButtonWithTitle:cancelSt];
		[popup setCancelButtonIndex:[popup numberOfButtons] - 1];
		if (isDeviceIPad) {
			[popup showFromBarButtonItem:[[self navigationItem] rightBarButtonItem] animated:YES];
		} else {
			[popup showInView:self.view];
		}
	}
}
- (void)viewDidLoad
{
	[super viewDidLoad];
	self.title = @"Favorites";
	UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
	[refreshControl addTarget:self action:@selector(refreshView:) forControlEvents:UIControlEventValueChanged];
	[self.tableView addSubview:refreshControl];
	[self Refresh];
}
- (NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	return nil;
}
- (void)loadView
{
	[super loadView];	
	[self setRightButton];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [[self.allFavURLs allKeys] count];
}
- (void)closeMImport
{
	[self dismissViewControllerAnimated:YES completion:nil];
}
- (void)refreshView:(UIRefreshControl *)refresh
{
	[self Refresh];
	[refresh endRefreshing];
}
- (void)actionSheet:(UIActionSheet *)alert clickedButtonAtIndex:(NSInteger)button 
{
	NSString* contextAlert = [alert context];
	NSString* buttonTitle = [[alert buttonTitleAtIndex:button] copy];
	
	if (button == [alert cancelButtonIndex]) {
		return;
	}
	if(contextAlert&&[contextAlert isEqualToString:@"more"]) {
		
		if([buttonTitle isEqualToString:@"Import From..."]) {
			openImportFrom(self);
		}
		
		return;
	}
}
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath 
{
	return	YES;
}
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	@try {
		if(indexPath.section == 0) {
			NSMutableDictionary* mutFavs = [self.allFavURLs mutableCopy];
			[mutFavs removeObjectForKey:[mutFavs allKeys][indexPath.row]];
			[[NSUserDefaults standardUserDefaults] setObject:mutFavs forKey:@"MImport-allFavURLs"];
			[[NSUserDefaults standardUserDefaults] synchronize];
			[self Refresh];
			return;
		}
	} @catch (NSException * e) {
	}
}
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
	if(section == [self numberOfSectionsInTableView:tableView]-1) {
		return getHeaderName();
	}
	return [super tableView:tableView titleForFooterInSection:section];
}
@end


@implementation MImportDirBrowserController
@synthesize path = _path, files = _files, selectedRows = _selectedRows, editRow = _editRow, contentDir = _contentDir, kImageAudio = _kImageAudio, hud;
- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
	startServer();
    if (self) {
		self.selectedRows = [NSMutableArray array];
    }
    return self;
}
- (NSString*)pathForFile:(NSString*)file
{
	return [self.path stringByAppendingPathComponent:file];
}
- (BOOL)fileIsDirectory:(NSString*)file
{
	BOOL isDir = NO;
	if(id isDirValue = [[[self.contentDir objectForKey:@"content"] objectForKey:file] objectForKey:@"isDir"]) {
		isDir = [isDirValue boolValue];
	}	
	return isDir;
}
- (BOOL)isMediaSupported:(NSString*)ext
{
	if(ext&&([ext isEqualToString:@"mp3"] || // ok
	   [ext isEqualToString:@"aac"] || // ok
	   [ext isEqualToString:@"m4a"] || // ok
	   [ext isEqualToString:@"m4r"] || // ok
	   [ext isEqualToString:@"m4b"] || // ok
	   [ext isEqualToString:@"wav"] || // ok
	   [ext isEqualToString:@"aif"] || // ok
	   [ext isEqualToString:@"aiff"] || // ok
	   [ext isEqualToString:@"aifc"] || // ok
	   [ext isEqualToString:@"caf"] || // ok
	   [ext isEqualToString:@"amr"] || // ok
	   
	   [ext isEqualToString:@"mp4"] || // ok
	   [ext isEqualToString:@"m4v"] || // ok
	   [ext isEqualToString:@"mov"] || // ok
	   [ext isEqualToString:@"3gp"] || // ok
	   
	   [ext isEqualToString:@"zip"] || // ok
	   [ext isEqualToString:@"rar"] // ok
	   )) {
		return YES;
	}
	return NO;
}
- (BOOL)extensionIsSupported:(NSString*)ext
{
	if(showAllFileTypes) {
		return YES;
	}
	return [self isMediaSupported:ext];
}
- (void)Refresh
{
	startServer();
	if (!self.path) {
		self.path = kPathWork;
	}
	NSMutableArray* tempFiles = [NSMutableArray array];
	NSError *error = nil;
	//self.files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.path error:&error]?:[NSArray array];
	__strong NSURL *pathURL = fixedMImportURLCachedWithURL([NSURL fileURLWithPath:self.path], @"dir");
	//NSLog(@"**** pathURL: %@", pathURL);
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:pathURL];
	request.cachePolicy = NSURLRequestReloadIgnoringLocalAndRemoteCacheData;
	__autoreleasing NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:&error]?:[NSData data];
	if(error) {
		dispatch_async(dispatch_get_main_queue(), ^(void) {
			NSString* titleSt = @"MImport";
			NSString* messageSt = [error description];
			NSString* okSt = @"OK";
			
			if(%c(UIAlertController) != nil) {
				UIAlertController* alert = [%c(UIAlertController) alertControllerWithTitle:titleSt message:messageSt preferredStyle:UIAlertControllerStyleAlert];
				UIAlertAction* defaultAction = [%c(UIAlertAction) actionWithTitle:okSt style:UIAlertActionStyleDefault handler:nil];
				[alert addAction:defaultAction];
				[topMostController() presentViewController:alert animated:YES completion:nil];
			} else {
				UIAlertView *alert = [[%c(UIAlertView) alloc] initWithTitle:titleSt message:messageSt delegate:nil cancelButtonTitle:okSt otherButtonTitles:nil];
				[alert show];
			}
		});
	}
	//NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil]?:@{};
	NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
	//NSLog(@"response == %@", [unarchiver decodeObjectForKey:@"response"]);
	self.contentDir = [unarchiver?[unarchiver decodeObjectForKey:@"response"]?:@{}:@{} copy];
	self.files = [[self.contentDir objectForKey:@"content"]?:@{} allKeys];
	self.files = [self.files sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
	
	for(NSString*file in self.files) {
		BOOL isdir = [self fileIsDirectory:file];
		if(isdir) {
			[tempFiles addObject:file];
		} else {
			NSString *ext = [[file pathExtension]?:@"" lowercaseString];
			if ([self extensionIsSupported:ext]) {
				[tempFiles addObject:file];
			}
		}
	}
	self.files = [tempFiles copy];
	self.title = [self.path lastPathComponent];
	self.navigationItem.backBarButtonItem.title = [[self.path lastPathComponent] lastPathComponent];
	[self.tableView reloadData];
}
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
	[[MImportTapMenu sharedInstance] _deviceOrientationDidChange];
	[self Refresh];
}
- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
	__strong UIBarButtonItem* kBTClose = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:self action:@selector(closeMImport)];
	kBTClose.tag = 4;	
	if (self.navigationController.navigationBar.backItem == NULL) {
		self.navigationItem.leftBarButtonItem = kBTClose;
	}
	
	if(receivedURLMImport) {
		MImportEditTagListController* NVBFromURL = [[%c(MImportEditTagListController) alloc] initWithURL:[receivedURLMImport copy]];
		NVBFromURL.isFromURL = YES;
		[self.navigationController pushViewController:NVBFromURL animated:YES];
		receivedURLMImport = nil;
	}
}
- (void)setRightButton
{
	__strong UIBarButtonItem * kBTRight;
	__strong UIBarButtonItem* kBTClose = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:self action:@selector(closeMImport)];
	__strong UIBarButtonItem *noButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"•••" style:UIBarButtonItemStylePlain target:self action:@selector(showOptions)];
	noButtonItem.tag = 4;
	self.navigationItem.rightBarButtonItems = @[kBTClose, noButtonItem];
	
	if(self.editRow) {
		kBTRight = [[UIBarButtonItem alloc] initWithTitle:[[NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/PhotoLibrary.framework"]?:[NSBundle mainBundle] localizedStringForKey:@"IMPORT_SELECTED" value:@"Import Selected" table:@"PhotoLibrary"] style:UIBarButtonItemStylePlain target:self action:@selector(selectRow)];
		__strong UIBarButtonItem *kCancel = [[UIBarButtonItem alloc] initWithTitle:[[NSBundle bundleWithPath:@"/System/Library/Frameworks/UIKit.framework"]?:[NSBundle mainBundle] localizedStringForKey:@"Cancel" value:@"Cancel" table:nil] style:UIBarButtonItemStylePlain target:self action:@selector(cancelSelectRow)];
		__strong UIBarButtonItem *kSelectAll = [[UIBarButtonItem alloc] initWithTitle:[[NSBundle bundleWithPath:@"/System/Library/Frameworks/UIKit.framework"]?:[NSBundle mainBundle] localizedStringForKey:@"Select All" value:@"Select All" table:nil] style:UIBarButtonItemStylePlain target:self action:@selector(selectAllRow)];
		kBTRight.tag = 4;
		kCancel.tag = 4;
		if([self.selectedRows count] > 0) {
			self.navigationItem.rightBarButtonItems = @[kBTClose, kCancel, kBTRight, ];
		} else {
			self.navigationItem.rightBarButtonItems = @[kBTClose, kCancel, kSelectAll, ];
		}		
	} else {
		self.navigationItem.rightBarButtonItems = @[kBTClose, noButtonItem];
	}
	
}
- (void)showOptions
{
	NSString* importSt = @"Import From...";
	NSString* cancelSt = [[NSBundle bundleWithPath:@"/System/Library/Frameworks/UIKit.framework"]?:[NSBundle mainBundle] localizedStringForKey:@"Cancel" value:@"Cancel" table:nil];
	NSString* selectSt = [[NSBundle bundleWithPath:@"/System/Library/Frameworks/UIKit.framework"]?:[NSBundle mainBundle] localizedStringForKey:@"Select" value:@"Select" table:nil];
	NSString* openSt = @"Open subfolder";
	NSString* fileTypeSt = @"Allow/Disallow Any File Type";
	if(%c(UIAlertController) != nil) {
		UIAlertController *alert = [%c(UIAlertController) alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
		actionShetModel* model = [[actionShetModel alloc] init];
		[model setContext:@"more"];
		if(!self.editRow && ([self.files count]>0)) {
			UIAlertAction* actionSelect = [%c(UIAlertAction) actionWithTitle:selectSt style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
				model.buttonName = selectSt;
				[self actionSheet:(UIActionSheet *)model clickedButtonAtIndex:1];
			}];
			[alert addAction:actionSelect];
		}
		UIAlertAction* actionFileType = [%c(UIAlertAction) actionWithTitle:fileTypeSt style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
			model.buttonName = fileTypeSt;
			[self actionSheet:(UIActionSheet *)model clickedButtonAtIndex:1];
		}];
		[alert addAction:actionFileType];
		if(self.path && [self.path lastPathComponent]!=nil && [self.path lastPathComponent].length > 0) {
			UIAlertAction* actionOpen = [%c(UIAlertAction) actionWithTitle:openSt style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
				model.buttonName = openSt;
				[self actionSheet:(UIActionSheet *)model clickedButtonAtIndex:1];
			}];
			[alert addAction:actionOpen];
		}
		UIAlertAction* actionImport = [%c(UIAlertAction) actionWithTitle:importSt style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
			model.buttonName = importSt;
			[self actionSheet:(UIActionSheet *)model clickedButtonAtIndex:1];
		}];
		[alert addAction:actionImport];
		UIAlertAction *cancel = [%c(UIAlertAction) actionWithTitle:cancelSt style:UIAlertActionStyleCancel handler:nil];
		[alert addAction:cancel];
		[self presentViewController:alert animated:YES completion:nil];
	} else {
		UIActionSheet *popup = [[%c(UIActionSheet) alloc] initWithTitle:nil delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
		[popup setContext:@"more"];	
		if(!self.editRow && ([self.files count]>0)) {
			[popup addButtonWithTitle:selectSt];
		}	
		[popup addButtonWithTitle:fileTypeSt];
		if(self.path && [self.path lastPathComponent]!=nil && [self.path lastPathComponent].length > 0) {
			[popup addButtonWithTitle:openSt];
		}
		[popup addButtonWithTitle:importSt];
		[popup addButtonWithTitle:cancelSt];
		[popup setCancelButtonIndex:[popup numberOfButtons] - 1];
		if (isDeviceIPad) {
			[popup showFromBarButtonItem:[[self navigationItem] rightBarButtonItem] animated:YES];
		} else {
			[popup showInView:self.view];
		}
	}
}
- (void)selectAllRow
{
	self.selectedRows = [NSMutableArray array];
	for(int i = 0; i < [self tableView:(UITableView*)self numberOfRowsInSection:0]; i++) {
		NSIndexPath *indexPath = [NSIndexPath indexPathForRow:i inSection:0];
		UITableViewCell *cell = [self tableView:self.tableView cellForRowAtIndexPath:indexPath];
		if(cell) {
			if(cell.accessoryType != UITableViewCellAccessoryDisclosureIndicator) {
				[self.selectedRows addObject:@(indexPath.row)];
			}
		}
	}
	[self Refresh];
	[self setRightButton];
}
- (void)viewDidLoad
{
	[super viewDidLoad];
	UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
	[refreshControl addTarget:self action:@selector(refreshView:) forControlEvents:UIControlEventValueChanged];
	[self.tableView addSubview:refreshControl];
	
	self.tableView.allowsMultipleSelection = YES;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:NO];
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];	
	if(cell.accessoryType == UITableViewCellAccessoryDisclosureIndicator) {		
		return;
	}	
    
	if ([self.selectedRows containsObject:@(indexPath.row)]) {
		[self.selectedRows removeObject:@(indexPath.row)];
	}
	
	if(cell.accessoryType == UITableViewCellAccessoryNone) {
		cell.accessoryType = UITableViewCellAccessoryCheckmark;
		[self.selectedRows addObject:@(indexPath.row)];
	} else {
		cell.accessoryType = UITableViewCellAccessoryNone;
	}
	[self setRightButton];
}

- (void)cancelSelectRow
{
	self.editRow = NO;
	self.selectedRows = [NSMutableArray array];
	[self Refresh];
	[self setRightButton];
}
- (void)loadView
{
	[super loadView];	
	[self setRightButton];
}

- (void)selectRow
{
	self.editRow = !self.editRow;
	[self setRightButton];
	int total = [self.selectedRows count];
	if(!self.editRow && (total > 0)) {
		if(!self.hud) {
			hud = [[UIProgressHUD alloc] init];
		}
		[hud setText:@"Loading..."];
		[hud showInView:self.view];
		[self.view setUserInteractionEnabled:NO];
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			int index = 0;
			for(id indexNowValue in self.selectedRows) {
				index++;
				int indexNow = [indexNowValue intValue];
				NSString *file = [self.files objectAtIndex:indexNow];
				NSString *path = [self pathForFile:file];
				dispatch_async(dispatch_get_main_queue(), ^(void) {
					[hud setText:[NSString stringWithFormat:@"Adding %d of %d ...", index, total]];
				});
				MImport_import([NSURL fileURLWithPath:path], nil, YES);
			}
			dispatch_async(dispatch_get_main_queue(), ^(void) {
				[self.view setUserInteractionEnabled:YES];
				[hud hide];
				[self cancelSelectRow];
				[self closeMImport];
			});
		});
	}
}
- (void)closeMImport
{
	[self dismissViewControllerAnimated:YES completion:nil];
}
- (void)refreshView:(UIRefreshControl *)refresh
{
	[self Refresh];
	[refresh endRefreshing];
}
- (NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	return self.path;
}
- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section
{
    if([view isKindOfClass:[UITableViewHeaderFooterView class]]) {
        UITableViewHeaderFooterView *tableViewHeaderFooterView = (UITableViewHeaderFooterView *) view;
        tableViewHeaderFooterView.textLabel.text = self.path;
    }
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.files count];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
		UILongPressGestureRecognizer *lpgr = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
		lpgr.minimumPressDuration = 0.8; //seconds
		lpgr.delegate = (id)self;
		[self.tableView addGestureRecognizer:lpgr];
		//cell.textLabel.font = [UIFont fontWithName: @"Arial" size:14.0];
		//cell.detailTextLabel.font = [UIFont fontWithName: @"Arial" size:11.0];
    }
	NSString *file = [self.files objectAtIndex:indexPath.row];
	//NSString *path = [self pathForFile:file];
	static __strong UIImage* kIconFolder = nil;//[[UIImage imageWithImage:[UIImage imageNamed:@"folder.png"]] copy];
	BOOL isdir = [self fileIsDirectory:file];
	//[[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isdir];
	//NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
	//int size = [attributes[NSFileSize] intValue];
	int size = 0;
	if(id sizeValue = [[[self.contentDir objectForKey:@"content"] objectForKey:file] objectForKey:@"size"]) {
		size = [sizeValue intValue];
	}
	BOOL isLink = NO;
	if(id isLinkValue = [[[self.contentDir objectForKey:@"content"] objectForKey:file] objectForKey:@"isLink"]) {
		isLink = [isLinkValue boolValue];
	}
	//cell.textLabel.text = file;
	cell.textLabel.text =  file;
	
	UIColor* labC = nil;
	@try {
		labC = [UIColor labelColor];
	}@catch(NSException*e) {
		labC = [UIColor blackColor];
	}
	
	cell.textLabel.textColor = isLink&&isdir ? [UIColor blueColor] : labC;
	cell.accessoryType = isdir ? UITableViewCellAccessoryDisclosureIndicator : [self.selectedRows containsObject:@(indexPath.row)]?UITableViewCellAccessoryCheckmark:UITableViewCellAccessoryNone;
	cell.imageView.image = isdir ? kIconFolder : nil;
	NSString* kKB = @"%.f KB";
	NSString* kMB = @"%.1f MB";
	cell.detailTextLabel.text = isdir ? nil : [NSString stringWithFormat:size>=1048576?kMB:kKB, size>=1048576?(float)size/1048576:(float)size/1024];
	if (!isdir) {
		NSString *ext = [[file pathExtension]?:@"" lowercaseString];
		if ([self extensionIsSupported:ext]) {
			
			cell.imageView.image = kIconMimportGet();
	    } else {
			//static __strong UIImage* kImageInstall = [[UIImage imageWithImage:[UIImage imageNamed:@"install.png"]] copy];
			cell.imageView.image = nil;
		}
	} else {
		
		cell.imageView.image = kImageDirGet();
	}
	
    return cell;
}
-(void)handleLongPress:(UILongPressGestureRecognizer *)gestureRecognizer
{
	@try{
    CGPoint p = [gestureRecognizer locationInView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:p];
    if (indexPath != nil && gestureRecognizer.state == UIGestureRecognizerStateBegan) {
		[[MImportTapMenu sharedInstance] setPathFav:nil];
		NSString *file = [self.files objectAtIndex:indexPath.row];
		NSString *path = [self pathForFile:file];
		BOOL isdir = [self fileIsDirectory:file];
		if(isdir) {
			[[MImportTapMenu sharedInstance] setPathFav:path];
			NSString* cancelSt = [[NSBundle bundleWithPath:@"/System/Library/Frameworks/UIKit.framework"]?:[NSBundle mainBundle] localizedStringForKey:@"Cancel" value:@"Cancel" table:nil];
			if(%c(UIAlertController) != nil) {
				UIAlertController *alert = [%c(UIAlertController) alertControllerWithTitle:file message:nil preferredStyle:UIAlertControllerStyleActionSheet];
				UIAlertAction* Action = [%c(UIAlertAction) actionWithTitle:@"Add To Favorites" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
					UIActionSheet* model = (UIActionSheet*)[[actionShetModel alloc] init];
					[(MImportTapMenu*)[MImportTapMenu sharedInstance] actionSheet:(UIActionSheet *)model clickedButtonAtIndex:1];
				}];
				[alert addAction:Action];
				UIAlertAction *cancel = [%c(UIAlertAction) actionWithTitle:cancelSt style:UIAlertActionStyleCancel handler:nil];
				[alert addAction:cancel];
				[self presentViewController:alert animated:YES completion:nil];
			} else {
				UIActionSheet *popup = [[%c(UIActionSheet) alloc] initWithTitle:file delegate:[MImportTapMenu sharedInstance] cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
				[popup addButtonWithTitle:@"Add To Favorites"];
				[popup addButtonWithTitle:cancelSt];
				[popup setCancelButtonIndex:[popup numberOfButtons] - 1];
				if (isDeviceIPad) {
					[popup showFromBarButtonItem:[[self navigationItem] rightBarButtonItem] animated:YES];
				} else {
					[popup showInView:self.view];
				}
			}
		}
    }
	} @catch (NSException * e) {
	}
}
- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if(self.editRow) {
		return indexPath;
	}
	NSString *file = [self.files objectAtIndex:indexPath.row];
	NSString *path = [self pathForFile:file];
	if ([self fileIsDirectory:file]) {
		if([self.path isEqualToString:path]) {
			return nil;
		}
		MImportDirBrowserController *dbtvc = [[[MImportDirBrowserController alloc] init] initWithStyle:self.tableView.style];
		dbtvc.path = path;
		@try {
			[self.navigationController pushViewController:dbtvc animated:YES];
		} @catch (NSException * e) {
		}
    } else {
		__strong NSURL *fileServerURL = fixedMImportURLCachedWithURL([NSURL fileURLWithPath:path], @"file");
		NSDictionary* piDict = fileTagsAtURL(fileServerURL);
		NSString* cancelSt = [[NSBundle bundleWithPath:@"/System/Library/Frameworks/UIKit.framework"]?:[NSBundle mainBundle] localizedStringForKey:@"Cancel" value:@"Cancel" table:nil];
		NSString* extractHereSt = @"Extract Here";
		NSString* importSt = [[NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/PhotoLibrary.framework"]?:[NSBundle mainBundle] localizedStringForKey:@"IMPORT" value:@"Import" table:@"PhotoLibrary"];
		NSString* playSt = @"Play";
		NSString* deleteSt = [[NSBundle bundleWithPath:@"/System/Library/Frameworks/UIKit.framework"]?:[NSBundle mainBundle] localizedStringForKey:@"Delete" value:@"Delete" table:nil];
		
		if(%c(UIAlertController) != nil) {
			UIAlertController *alert = [%c(UIAlertController) alertControllerWithTitle:file message:nil preferredStyle:UIAlertControllerStyleActionSheet];
			actionShetModel* model = [[actionShetModel alloc] init];
			model.tag = indexPath.row;
			if([piDict[kIsFileZip] boolValue]) {
				UIAlertAction* actionExtract = [%c(UIAlertAction) actionWithTitle:extractHereSt style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
					model.buttonName = extractHereSt;
					[self actionSheet:(UIActionSheet *)model clickedButtonAtIndex:1];
				}];
				[alert addAction:actionExtract];
			} else {
				UIAlertAction* actionImport = [%c(UIAlertAction) actionWithTitle:importSt style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
					model.buttonName = importSt;
					[self actionSheet:(UIActionSheet *)model clickedButtonAtIndex:1];
				}];
				[alert addAction:actionImport];
				UIAlertAction* actionPlay = [%c(UIAlertAction) actionWithTitle:playSt style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
					model.buttonName = playSt;
					[self actionSheet:(UIActionSheet *)model clickedButtonAtIndex:1];
				}];
				[alert addAction:actionPlay];
			}
			UIAlertAction *del = [%c(UIAlertAction) actionWithTitle:deleteSt style:UIAlertActionStyleDestructive handler:^(UIAlertAction * action) {
				model.buttonName = deleteSt;
				[self actionSheet:(UIActionSheet *)model clickedButtonAtIndex:1];
			}];
			[alert addAction:del];
			UIAlertAction *cancel = [%c(UIAlertAction) actionWithTitle:cancelSt style:UIAlertActionStyleCancel handler:nil];
			[alert addAction:cancel];
			[self presentViewController:alert animated:YES completion:nil];
		} else {
			UIActionSheet *popup = [[%c(UIActionSheet) alloc] initWithTitle:file delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
			if([piDict[kIsFileZip] boolValue]) {
				[popup addButtonWithTitle:extractHereSt];
			} else {
				[popup addButtonWithTitle:importSt];
				[popup addButtonWithTitle:playSt];
			}
			[popup setDestructiveButtonIndex:[popup addButtonWithTitle:deleteSt]];
			[popup addButtonWithTitle:cancelSt];
			[popup setCancelButtonIndex:[popup numberOfButtons] - 1];
			popup.tag = indexPath.row;
			if (isDeviceIPad) {
				[popup showFromBarButtonItem:[[self navigationItem] rightBarButtonItem] animated:YES];
			} else {
				[popup showInView:self.view];
			}
		}
	}
	return nil;
}
- (void)actionSheet:(UIActionSheet *)alert clickedButtonAtIndex:(NSInteger)button 
{
	if (button == [alert cancelButtonIndex]) {
		return;
	}
	
	NSString* contextAlert = [alert context];
	NSString* buttonTitle = [[alert buttonTitleAtIndex:button] copy];
	
	if(contextAlert&&[contextAlert isEqualToString:@"more"]) {
		
		if ([buttonTitle isEqualToString:[[NSBundle bundleWithPath:@"/System/Library/Frameworks/UIKit.framework"]?:[NSBundle mainBundle] localizedStringForKey:@"Select" value:@"Select" table:nil]]) {
			[self performSelector:@selector(selectRow) withObject:nil afterDelay:0];
		} else if ([buttonTitle isEqualToString:[[NSBundle bundleWithPath:@"/System/Library/Frameworks/UIKit.framework"]?:[NSBundle mainBundle] localizedStringForKey:@"Cancel" value:@"Cancel" table:nil]]) {
			[self performSelector:@selector(cancelSelectRow) withObject:nil afterDelay:0];
		} else if ([buttonTitle isEqualToString:[[NSBundle bundleWithPath:@"/System/Library/Frameworks/UIKit.framework"]?:[NSBundle mainBundle] localizedStringForKey:@"Select All" value:@"Select All" table:nil]]) {
			[self performSelector:@selector(selectAllRow) withObject:nil afterDelay:0];
		} else if ([buttonTitle isEqualToString:@"Import From..."]) {
			openImportFrom(self);
		} else if ([buttonTitle isEqualToString:@"Allow/Disallow Any File Type"]) {
			toogleShowAllFileTypes();
			[self Refresh];
		} else if ([buttonTitle isEqualToString:@"Open subfolder"]) {
			@try {
				MImportDirBrowserController *dbtvc = [[[MImportDirBrowserController alloc] init] initWithStyle:self.tableView.style];
				dbtvc.path = [self.path stringByDeletingLastPathComponent];
				[self.navigationController pushViewController:dbtvc animated:YES];
			} @catch (NSException * e) {
			}
		}
		return;
	}
	
	NSString *file = [[self.files objectAtIndex:[alert tag]] copy];
	NSString *path = [[self pathForFile:file] copy];
	
	if([buttonTitle isEqualToString:[[NSBundle bundleWithPath:@"/System/Library/Frameworks/UIKit.framework"]?:[NSBundle mainBundle] localizedStringForKey:@"Delete" value:@"Delete" table:nil]]) {
		if(!self.hud) {
			hud = [[UIProgressHUD alloc] init];
		}
		[hud setText:[NSString stringWithFormat:@"%@ %@", @"Deleting", [path lastPathComponent]]];
		[hud showInView:self.view];
		[self.view setUserInteractionEnabled:NO];
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			BOOL success = fileOperation(fileOperationDelete, path, nil, nil);
			if(success) {
				dispatch_async(dispatch_get_main_queue(), ^(void) {
					[self Refresh];
				});
			}
			dispatch_async(dispatch_get_main_queue(), ^(void) {
				[self.view setUserInteractionEnabled:YES];
				[hud hide];
			});
		});
		return;
	} else if([buttonTitle isEqualToString:@"Extract Here"]) {
		if(!self.hud) {
			hud = [[UIProgressHUD alloc] init];
		}
		[hud setText:[NSString stringWithFormat:@"%@ %@", @"Extracting", [path lastPathComponent]]];
		[hud showInView:self.view];
		[self.view setUserInteractionEnabled:NO];
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			NSString* pathDest = nil;
			BOOL success = fileOperation(fileOperationExtract, path, nil, &pathDest);
			dispatch_async(dispatch_get_main_queue(), ^(void) {
				[self.view setUserInteractionEnabled:YES];
				[hud hide];
			});
			if(success) {
				dispatch_async(dispatch_get_main_queue(), ^(void) {
					[self Refresh];
					if(pathDest) {
						MImportDirBrowserController *dbtvc = [[[MImportDirBrowserController alloc] init] initWithStyle:self.tableView.style];
						dbtvc.path = pathDest;
						@try {
							[self.navigationController pushViewController:dbtvc animated:YES];
						} @catch (NSException * e) {
						}
					}
				});
			}
			
		});
		return;
	} else if([buttonTitle isEqualToString:@"Play"]) {
		playFromURLWithViewController(self, [NSURL fileURLWithPath:path]);
		return;
	} else if([buttonTitle isEqualToString:[[NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/PhotoLibrary.framework"]?:[NSBundle mainBundle] localizedStringForKey:@"IMPORT" value:@"Import" table:@"PhotoLibrary"]]) {
		NSString *ext = [[file pathExtension]?:@"" lowercaseString];
		if([self extensionIsSupported:ext]) {
			@try {	
				[self.navigationController pushViewController:[[%c(MImportEditTagListController) alloc] initWithURL:[NSURL fileURLWithPath:path]] animated:YES];
			} @catch (NSException * e) {
			}
		} else {
			dispatch_async(dispatch_get_main_queue(), ^(void) {
				NSString* titleSt = @"MImport";
				NSString* messageSt = [NSString stringWithFormat:@"%@ (%@)", [[NSBundle bundleWithPath:@"/System/Library/Frameworks/UIKit.framework"]?:[NSBundle mainBundle] localizedStringForKey:@"Doesn't support the file type" value:@"Doesn't support the file type" table:nil], ext];
				NSString* okSt = @"OK";
				
				if(%c(UIAlertController) != nil) {
					UIAlertController* alert = [%c(UIAlertController) alertControllerWithTitle:titleSt message:messageSt preferredStyle:UIAlertControllerStyleAlert];
					UIAlertAction* defaultAction = [%c(UIAlertAction) actionWithTitle:okSt style:UIAlertActionStyleDefault handler:nil];
					[alert addAction:defaultAction];
					[topMostController() presentViewController:alert animated:YES completion:nil];
				} else {
					UIAlertView *alert = [[%c(UIAlertView) alloc] initWithTitle:titleSt message:messageSt delegate:nil cancelButtonTitle:okSt otherButtonTitles:nil];
					[alert show];
				}
			});
		}
		return;
	}
	return;
}
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath 
{
	return	YES;
}
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	@try {
		NSString *file = [[self.files objectAtIndex:indexPath.row] copy];
		NSString *path = [[self pathForFile:file] copy];
		
		if(!self.hud) {
			hud = [[UIProgressHUD alloc] init];
		}
		[hud setText:[NSString stringWithFormat:@"%@ %@", @"Deleting", [path lastPathComponent]]];
		[hud showInView:self.view];
		[self.view setUserInteractionEnabled:NO];
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			BOOL success = fileOperation(fileOperationDelete, path, nil, nil);
			if(success) {
				dispatch_async(dispatch_get_main_queue(), ^(void) {
					[self Refresh];
				});
			}
			dispatch_async(dispatch_get_main_queue(), ^(void) {
				[self.view setUserInteractionEnabled:YES];
				[hud hide];
			});
		});
		return;
	} @catch (NSException * e) {
	}
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
	if(section == [self numberOfSectionsInTableView:tableView]-1) {
		return getHeaderName();
	}
	return [super tableView:tableView titleForFooterInSection:section];
}
@end





%hook NSURL
- (id)scheme
{
	id ret = %orig;
	if(ret) {
		@try{
			if([ret isEqualToString:@"music"] && [[self lastPathComponent] isEqualToString:@"mimport"]) {
				if(NSString* query = [self query]) {
					NSMutableDictionary *queryStringDictionary = [[NSMutableDictionary alloc] init];
					NSArray *urlComponents = [query componentsSeparatedByString:@"&"];
					for (NSString *keyValuePair in urlComponents) {
						NSArray *pairComponents = [keyValuePair componentsSeparatedByString:@"="];
						NSString *key = [[pairComponents firstObject] stringByRemovingPercentEncoding];
						NSString *value = [[pairComponents lastObject] stringByRemovingPercentEncoding];
						queryStringDictionary[key] = value;
					}
					
					receivedURLMImport_autoFetchTags = [queryStringDictionary objectForKey:@"fetchTags"]!=nil;
					
					if([queryStringDictionary objectForKey:@"path"] && (!receivedURLMImport || (receivedURLMImport && ![[queryStringDictionary objectForKey:@"path"] isEqualToString:[receivedURLMImport absoluteString]]))) {
						needShowAgainMImportURL = YES;
						receivedURLMImport = fixURLRemoteOrLocalWithPath([queryStringDictionary objectForKey:@"path"]);
						//NSLog(@"***** DETECTEDRECEIVE URL: %@", receivedURLMImport);
						[[NSNotificationCenter defaultCenter] performSelector:@selector(postNotificationName:) withObject:@"com.julioverne.mimport/callback" afterDelay:0.5];
					} else if(queryStringDictionary[@"pathBase"] && (!receivedURLMImport || (receivedURLMImport && ![queryStringDictionary[@"pathBase"] isEqualToString:[receivedURLMImport absoluteString]]))) {
						needShowAgainMImportURL = YES;
						NSString* receivedURLMImportBase64 = queryStringDictionary[@"pathBase"];
						receivedURLMImportBase64 = [receivedURLMImportBase64 stringByReplacingOccurrencesOfString:@"_" withString:@"/"];
						receivedURLMImportBase64 = [receivedURLMImportBase64 stringByReplacingOccurrencesOfString:@"-" withString:@"+"];
						receivedURLMImportBase64 = [receivedURLMImportBase64 stringByReplacingOccurrencesOfString:@"." withString:@"="];
						receivedURLMImport = [NSURL URLWithString:[[NSString alloc] initWithData:base64DataFromString(receivedURLMImportBase64) encoding:NSUTF8StringEncoding]];
						//NSLog(@"***** DETECTED RECEIVE URL: %@", receivedURLMImport);
						[[NSNotificationCenter defaultCenter] performSelector:@selector(postNotificationName:) withObject:@"com.julioverne.mimport/callback" afterDelay:0.5];
					}
				}
				ret = @"https";
			}
		} @catch (NSException * e) {
		}
	}	
	return ret;
}
%end

@interface MusicOPageHeaderContentViewController : UIViewController
@property (assign) UIView* accessoryView;
@end

@interface UIBarButtonItem ()
- (id)createViewForNavigationItem:(id)arg1;
@end

%group MusicIOS10
%hook MusicOPageHeaderContentViewController
- (void)viewDidLoad
{
	%orig;
	@try {
	if(!((MusicOPageHeaderContentViewController*)self).accessoryView) {
		__strong UIBarButtonItem* kBTLaunch = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemOrganize target:self action:@selector(launchMImport)];
		UIView* btView = [kBTLaunch createViewForNavigationItem:nil];
		btView.tag = 4659;
		[(UIButton*)btView addTarget:self action:@selector(launchMImport) forControlEvents:UIControlEventTouchUpInside];
		((MusicOPageHeaderContentViewController*)self).accessoryView = btView;
	} else if (((MusicOPageHeaderContentViewController*)self).accessoryView&&((MusicOPageHeaderContentViewController*)self).accessoryView.tag!=4659) {
		__strong UIBarButtonItem* kBTLaunch = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemOrganize target:self action:@selector(launchMImport)];
		UIView* btView = [kBTLaunch createViewForNavigationItem:nil];
		btView.tag = 4659;
		[(UIButton*)btView addTarget:self action:@selector(launchMImport) forControlEvents:UIControlEventTouchUpInside];
		if(UIView* btViewOld = [((MusicOPageHeaderContentViewController*)self).view viewWithTag:4659]) {
			[btViewOld removeFromSuperview];
		}
		[((MusicOPageHeaderContentViewController*)self).view addSubview:btView];
	}
	}@catch(NSException* ex) {
	}
}
- (void)viewDidLayoutSubviews
{
	%orig;
	@try {
	if (((MusicOPageHeaderContentViewController*)self).accessoryView&&((MusicOPageHeaderContentViewController*)self).accessoryView.tag!=4659) {
		if(UIView* btView = [((MusicOPageHeaderContentViewController*)self).view viewWithTag:4659]) {
			CGRect asesFrame = ((MusicOPageHeaderContentViewController*)self).accessoryView.frame;
			[btView setFrame:CGRectMake(asesFrame.origin.x - (btView.frame.size.width + 5),  asesFrame.origin.y, btView.frame.size.width, btView.frame.size.height)];
		}
	}
	}@catch(NSException* ex) {
	}
}
%new
- (void)launchMImport
{
	//NSLog(@"*** launchMImport");
	if(isStartingServerInProgress) {
		return;
	}
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		startServer();
		dispatch_async(dispatch_get_main_queue(), ^(void) {
			launchMImportNow();
		});
	});
}
%end
%end



__attribute__((constructor)) static void initialize_mimport()
{
	%init;
	%init(MusicIOS10, MusicOPageHeaderContentViewController = objc_getClass("Music.PageHeaderContentViewController"));
	
	showAllFileTypes = [[[NSUserDefaults standardUserDefaults] objectForKey:@"MImport-AnyFile"]?:@NO boolValue];
}

__attribute__((destructor)) static void finalize_mimport()
{
	@autoreleasepool {
		unlink(mimport_running);
		unlink(mimport_running_uploader);
	}
}