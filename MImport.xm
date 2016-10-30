#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <sys/types.h>
#import <sys/stat.h>
#import <fcntl.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreFoundation/CFUserNotification.h>
#import <substrate.h>
#import "MImport.h"

@interface UIProgressHUD : UIView
- (void) hide;
- (void) setText:(NSString *)text;
- (void) showInView:(UIView *)view;
@end

@interface MImportSwithServer : NSObject
+ (instancetype)sharedInstance;
- (void)runThis;
@end

const char* mimport_running = "/private/var/mobile/Media/mimport_running";

static __strong NSString* kPathWork = @"/";// @"/private/var/mobile/Media/";
static __strong NSString* kTitle = @"title";
static __strong NSString* kAlbum = @"album";
static __strong NSString* kArtist = @"artist";
static __strong NSString* kGenre = @"genre";
static __strong NSString* kComposer = @"composer";
static __strong NSString* kYear = @"year";
static __strong NSString* kTrackNumber = @"trackNumber";
static __strong NSString* kTrackCount = @"trackCount";
static __strong NSString* kExplicit = @"explicit";
static __strong NSString* kArtwork = @"artwork";
static __strong NSString* kKindType = @"kind";
static __strong NSString* kDuration = @"approximate duration in seconds";
static __strong NSString* kUrlServer = [NSString stringWithFormat:[@"http://%@:%i/" substringToIndex:12], @"localhost", PORT_SERVER];

static __strong NSString* receivedURLMImport;
static BOOL needShowAgainMImportURL;


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

NSString* encodeBase64WithData(NSData* theData)
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
NSString* hmacSHA1BinBase64(NSString* data, NSString* key) 
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
NSString* urlEncodeUsingEncoding(NSString* encoding)
{
	static __strong NSString* kCodes = @"!*'\"();:@&=+$,?%#[] ";
	return (NSString*)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)encoding, NULL, (CFStringRef)kCodes, CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));
}

NSDictionary* getMusicInfo(NSDictionary* item)
{
	if(item) {
		@try {
			
			NSString *artist, *album, *album_artist, *track, *duration;
			artist = [[item objectForKey:kArtist]?:[NSString string] copy];
			album = [[item objectForKey:kAlbum]?:[NSString string] copy];
			album_artist = [[item objectForKey:@"albumArtist"]?:[NSString string] copy];
			track = [[item objectForKey:kTitle]?:[NSString string] copy];
			duration = [[[item objectForKey:kDuration]?:@(0) stringValue]?:[NSString string] copy];
			static __strong NSString* token = @"160203df69efabfaf0b50f2b7b82aaad0206ce701d1c55895ec22f";
			static __strong NSString* sigFormat = @"&signature=%@&signature_protocol=sha1";
			static __strong NSString* urlFormat = @"https://apic.musixmatch.com/ws/1.1/macro.subtitles.get?app_id=mac-ios-v2.0&usertoken=%@&q_duration=%@&tags=playing&q_album_artist=%@&q_track=%@&q_album=%@&page_size=1&subtitle_format=mxm&f_subtitle_length_max_deviation=1&user_language=pt&f_tracking_url=html&f_subtitle_length=%@&track_fields_set=ios_track_list&q_artist=%@&format=json";
			NSString* prepareString = [NSString stringWithFormat:urlFormat, token, duration, urlEncodeUsingEncoding(album_artist), urlEncodeUsingEncoding(track), urlEncodeUsingEncoding(album), duration, urlEncodeUsingEncoding(artist)];
			NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
			[formatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
			[formatter setDateFormat:@"yyyMMdd"];
			NSString* dateToday = [NSString stringWithFormat:@"%d", [[formatter stringFromDate:[NSDate date]] intValue]];
			NSURL* UrlString = [NSURL URLWithString:[prepareString stringByAppendingString:[NSString stringWithFormat:sigFormat, urlEncodeUsingEncoding(hmacSHA1BinBase64([prepareString stringByAppendingString:dateToday], @"secretsuper"))]]];
			NSDictionary* retLyric = nil;
			if(UrlString != nil) {
				NSError *error = nil;
				NSHTTPURLResponse *responseCode = nil;
				NSMutableURLRequest *Request = [[NSMutableURLRequest alloc]	initWithURL:UrlString cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:15.0];
				[Request setHTTPMethod:@"GET"];
				[Request setValue:@"default" forHTTPHeaderField:@"Cookie"];
				[Request setValue:@"default" forHTTPHeaderField:@"x-mxm-endpoint"];
				[Request setValue:@"Musixmatch/6.0.1 (iPhone; iOS 9.2.1; Scale/2.00)" forHTTPHeaderField:@"User-Agent"];
				NSData *receivedData = [NSURLConnection sendSynchronousRequest:Request returningResponse:&responseCode error:&error];
				if(receivedData && !error) {
					NSDictionary *JSON = [NSJSONSerialization JSONObjectWithData:receivedData?:[NSData data] options:NSJSONReadingMutableContainers error:nil];
					retLyric = [[[[[[[JSON objectForKey:@"message"] objectForKey:@"body"] objectForKey:@"macro_calls"] objectForKey:@"matcher.track.get"] objectForKey:@"message"] objectForKey:@"body"] objectForKey:@"track"];
				} else if (error) {
					UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"MImport" 
						    message:[error description]
						    delegate:nil
						    cancelButtonTitle:@"OK" 
						    otherButtonTitles:nil];
					[alert show];
				}
			}
			if(retLyric) {
				return retLyric;
			}			
		} @catch (NSException * e) {
		}
	}
	return [NSDictionary dictionary];
}

void MImport_import(NSString *mediaPath, NSDictionary *mediaInfo)
{
	if (access(mimport_running, F_OK) != 0) {
		if(open(mimport_running, O_CREAT)) {
		}
		usleep(1500000); //wait server start again.
	}
	@autoreleasepool {
	if(!mediaPath) {
		return;
	}
	if(!mediaInfo) {
		mediaInfo = [NSDictionary dictionary];
	}
	
	__strong NSURL *audioURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", kUrlServer, urlEncodeUsingEncoding(mediaPath)]];
	//__strong NSURL *audioFileURL = [NSURL fileURLWithPath:mediaPath];
	
	//AudioFileID fileID = nil;
	//AudioFileOpenURL((__bridge CFURLRef)audioURL, kAudioFileReadPermission, 0, &fileID);
	//CFDictionaryRef piDict = nil;
	//UInt32 piDataSize   = sizeof(piDict);   
	//AudioFileGetProperty( fileID, kAudioFilePropertyInfoDictionary, &piDataSize, &piDict);
	//if(!piDict) {
	//	piDict = (__bridge CFDictionaryRef)[NSMutableDictionary dictionary];
	//}
	//AudioFileClose(fileID);
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:audioURL];
	[request setHTTPMethod:@"POST"];
	request.cachePolicy = NSURLRequestReloadIgnoringLocalAndRemoteCacheData;
	NSError* error = nil;
	NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:&error];
	if(error) {
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"MImport" 
						    message:[error description]
						    delegate:nil
						    cancelButtonTitle:@"OK" 
						    otherButtonTitles:nil];
		[alert show];
	}
	CFDictionaryRef piDict = (__bridge CFDictionaryRef)[[NSJSONSerialization JSONObjectWithData:data?:[NSData data] options:kNilOptions error:NULL] copy];
	
	//NSLog(@"Server URL: %@ \n Path: %@ \n piDict: %@", [audioURL absoluteString], mediaPath, piDict);
	
	NSMutableDictionary* metaDataParse = [NSMutableDictionary dictionary];
	
	NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:AVAssetReferenceRestrictionForbidNone], AVURLAssetReferenceRestrictionsKey, nil];
    AVAsset *asset = [AVURLAsset URLAssetWithURL:audioURL options:options];
    for (NSString *format in [asset availableMetadataFormats]) {
        for (AVMetadataItem *item in [asset metadataForFormat:format]) {
            if ([[item commonKey] isEqualToString:kTitle]) {
				[metaDataParse setObject:[item value] forKey:kTitle];
            }
            if ([[item commonKey] isEqualToString:kArtist]) {
                [metaDataParse setObject:[item value] forKey:kArtist];
            }
            if ([[item commonKey] isEqualToString:@"albumName"]) {
                [metaDataParse setObject:[item value] forKey:@"albumName"];
            }
			if ([[item commonKey] isEqualToString:@"copyrights"]) {
                [metaDataParse setObject:[item value] forKey:@"copyright"];
            }
            if ([[item commonKey] isEqualToString:kArtwork]) {
                if ([[item value] isKindOfClass:[NSDictionary class]]) {
					[metaDataParse setObject:[(NSDictionary *)[item value] objectForKey:@"data"] forKey:kArtwork];
                } else {
					[metaDataParse setObject:[item value] forKey:kArtwork];
                }
			}
        }
	}
	
	NSString* ap = [NSTemporaryDirectory() stringByAppendingPathComponent:[[[mediaPath lastPathComponent] stringByDeletingPathExtension] stringByAppendingPathExtension:@"jpeg"]];
	NSData* imageData = [mediaInfo objectForKey:kArtwork]?:[metaDataParse objectForKey:kArtwork];
	
	if(!imageData) {
		NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString: [[[audioURL absoluteString] stringByDeletingPathExtension] stringByAppendingPathExtension:@"jpeg"] ]];
		request.cachePolicy = NSURLRequestReloadIgnoringLocalAndRemoteCacheData;
		imageData = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
		if(imageData) {
			if([imageData length] == 0) {
				imageData = nil;
			}
		}
		if(!imageData) {
			request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString: [[[audioURL absoluteString] stringByDeletingPathExtension] stringByAppendingPathExtension:@"jpg"] ]];
			request.cachePolicy = NSURLRequestReloadIgnoringLocalAndRemoteCacheData;
			imageData = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
		}
		if(imageData) {
			if([imageData length] == 0) {
				imageData = nil;
			}
		}
		if(!imageData) {
			request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString: [[[audioURL absoluteString] stringByDeletingPathExtension] stringByAppendingPathExtension:@"png"] ]];
			request.cachePolicy = NSURLRequestReloadIgnoringLocalAndRemoteCacheData;
			imageData = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
		}
		if(imageData) {
			if([imageData length] == 0) {
				imageData = nil;
			}
		}
	}
    if (imageData != nil) {
		UIImage* image = [UIImage imageWithData:imageData];
        [UIImageJPEGRepresentation(image, 1.0) writeToFile:ap atomically:YES];
    }
	
	NSString __strong*title, __strong*album, __strong*artist, __strong*copyright, __strong*genre, __strong*composer;
	
	title     = [mediaInfo objectForKey:kTitle]?:[metaDataParse objectForKey:kTitle]?:[(__bridge NSDictionary *)piDict objectForKey:kTitle]?:[[mediaPath lastPathComponent] stringByDeletingPathExtension]?:@"Unknown Title";
	album     = [mediaInfo objectForKey:kAlbum]?:[metaDataParse objectForKey:@"albumName"]?:[(__bridge NSDictionary *)piDict objectForKey:kAlbum]?:@"Unknown Album";
	artist    = [mediaInfo objectForKey:kArtist]?:[metaDataParse objectForKey:kArtist]?:[(__bridge NSDictionary *)piDict objectForKey:kArtist]?:@"Unknown Artist";
	copyright = [metaDataParse objectForKey:@"copyright"]?:[(__bridge NSDictionary *)piDict objectForKey:@"copyright"]?:@"\u2117 MImport.";
	genre     = [mediaInfo objectForKey:kGenre]?:[(__bridge NSDictionary *)piDict objectForKey:kGenre]?:@"";
	composer  = [mediaInfo objectForKey:kComposer]?:[(__bridge NSDictionary *)piDict objectForKey:kComposer]?:@"";
	
	
	int durationSecond = 0;
	int year = 2016;
	int trackNumber = 1;
	int trackCount = 1;
	int isExplicit = 0;
	
	durationSecond = [[(__bridge NSDictionary *)piDict objectForKey:kDuration]?:@(0) intValue];
	
	if(durationSecond == 0) {
		durationSecond = CMTimeGetSeconds(asset.duration);
	}	
	
	if(id yearID = [(__bridge NSDictionary *)piDict objectForKey:kYear]) {
		if([yearID isKindOfClass:[NSString class]]) {
		if([(NSString*)yearID length] == 4) {
			year = [yearID intValue]; 
		} else if([(NSString*)yearID length] > 4) {
			yearID = [yearID substringToIndex:4];
			year = [yearID intValue]; 
		}
		}
	}
	if(id TrackID = [(__bridge NSDictionary *)piDict objectForKey:@"track number"]) {
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
	
	
	
	//NSLog(@"title %@, *album %@, *artist %@, trackNumber %d, trackCount %d, year %d", title, album, artist, trackNumber, trackCount, year);
	
	long long itemGet = (arc4random() % 100000000) + 1;
	
	int itemID = itemGet;
	
	
	NSString* artworkURLString = [NSString stringWithFormat:@"%@%@:%@%@", @"http://", [audioURL host], [audioURL port], urlEncodeUsingEncoding(ap)];
	
	NSString *ext = [[mediaPath pathExtension] lowercaseString];
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
	
	SSDownloadMetadata *metad = [[SSDownloadMetadata alloc] initWithDictionary:@{
		@"purchaseDate": [NSDate date],
		@"is-purchased-redownload": @YES,
		
		@"URL": [audioURL absoluteString],
		
		@"artworkURL": artworkURLString,
		
		@"artwork-urls": @{
			@"default": @{
				@"url": artworkURLString,
			}, 
	        @"image-type": @"download-queue-item",
	    },
		
		@"songId": @(itemID),
		
		@"metadata": @{
			 //@"artistId": @(602767352),
	        @"artistName": artist,
	         //@"bitRate": @(256),
	        @"compilation": @NO,
	         //@"composerId": @(327699389),
	        @"composerName": composer,
	        @"copyright": copyright,
			@"description": copyright,
			@"longDescription": copyright,
			
	         //@"discCount": @(1),
	         //@"discNumber": @(1),
	        @"drmVersionNumber": @(0),
	        @"duration": @(durationSecond * 1000),
	        @"explicit": @(isExplicit),
	        @"fileExtension": ext,
	        @"gapless": @NO,
	        @"genre": genre,
	         //@"genreId": @(14),
	        @"isMasteredForItunes": @NO,
	        @"itemId": @(itemID),
	        @"itemName": title,
	        @"kind": kindType,
	        @"playlistArtistName": artist,
	         //@"playlistId": @(itemID),
	        @"playlistName": album,
	         //@"rank": @(1),
	        @"releaseDate": [NSDate date],
	         //@"s": @(143444),
	         //@"sampleRate": @(44100),
	        @"sort-album": album,
	        @"sort-artist": artist,
	        @"sort-composer": composer,
	        @"sort-name": title,
	        @"trackCount": @(trackCount),
	        @"trackNumber": @(trackNumber),
	         //@"vendorId": @(1883),
	         //@"versionRestrictions": @(16873077),
	         //@"xid": @"Universal:isrc:NZUM71300248",
	        @"year": @(year),
		},
		
		
		
	}];
	
	
	SSDownloadQueue *dlQueue = [[SSDownloadQueue alloc] initWithDownloadKinds:[SSDownloadQueue mediaDownloadKinds]];
	SSDownload *downl = [[SSDownload alloc] initWithDownloadMetadata:metad];
	
	//[downl setDownloadHandler:nil completionBlock:^{ }];
	
	if([dlQueue addDownload:downl]) {
		/*UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"MImport" 
						    message:@"Added successfully. Will import automatically."
						    delegate:nil
						    cancelButtonTitle:@"OK" 
						    otherButtonTitles:nil];
		[alert show];*/
	}
	
	}
}


static __strong UINavigationController *navCon;

@interface UITabBarItem (priv)
- (void)_setInternalTitle:(id)arg1;
@end
@interface MImportTapMenu : NSObject <UITabBarDelegate> {
	NSString *_pathFav;
}
@property(nonatomic,retain) NSString *pathFav;
+ (id)sharedInstance;
- (void)applyTabBarNavController:(UINavigationController*)navc;
@end

@implementation MImportTapMenu
@synthesize pathFav = _pathFav;
+ (id)sharedInstance
{
	static __strong MImportTapMenu* shared;
	if(!shared) {
		shared = [[[self class] alloc] init];
	}
	return shared;
}
- (void)tabBar:(UITabBar *)tabBar didSelectItem:(UITabBarItem *)item
{
    NSInteger selectedTag = tabBar.selectedItem.tag;
	MImportDirBrowserController *dbtvc = [[[MImportDirBrowserController alloc] init] initWithStyle:UITableViewStyleGrouped];
	dbtvc.path = @"/";
	[navCon setViewControllers:@[dbtvc] animated:NO];
	NSString* current_pt = @"/";
	NSString* patFav;
	if(selectedTag == 1) {
		patFav = @"/var/mobile/";
    } else if(selectedTag == 2) {
		patFav = [[NSUserDefaults standardUserDefaults] objectForKey:@"fav1"]?:@"/var/mobile/Documents/";
    } else if(selectedTag == 3) {
		patFav = [[NSUserDefaults standardUserDefaults] objectForKey:@"fav2"]?:@"/var/mobile/Downloads/";
    }
	for(NSString*path_now in [patFav componentsSeparatedByString:@"/"]) {
		if(path_now && [path_now length] > 0) {
			MImportDirBrowserController *dbtvc1 = [[[MImportDirBrowserController alloc] init] initWithStyle:UITableViewStyleGrouped];
			current_pt = [current_pt stringByAppendingPathComponent:path_now];
			dbtvc1.path = current_pt;
			[navCon pushViewController:dbtvc1 animated:NO];
		}
	}	
}
- (void)applyTabBarNavController:(UINavigationController*)navc
{
	float y = navCon.view.frame.size.height - 50;
	if(UIView* tabVi = [navCon.view viewWithTag:548]) {
		[tabVi removeFromSuperview];
		//y = 50;
	}
	UITabBar *myTabBar = [[UITabBar alloc] initWithFrame:CGRectMake(0, y, 320, 50)];
	myTabBar.delegate = self;
	myTabBar.tag = 548;
	
	
	
	[navCon.view addSubview:myTabBar];
	[myTabBar setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
	[myTabBar setFrame:CGRectMake(0, y, navCon.view.frame.size.width, myTabBar.frame.size.height)];
	UITabBarItem *tabBarItem1 = [[UITabBarItem alloc] initWithTitle:@"/" image:[[UIImage alloc] initWithContentsOfFile:[[NSBundle bundleWithPath:@"/Library/PreferenceBundles/MImport.bundle"] pathForResource:@"dir" ofType:@"png"]] tag:0];
	UITabBarItem *tabBarItem2 = [[UITabBarItem alloc] initWithTitle:@"mobile" image:[[UIImage alloc] initWithContentsOfFile:[[NSBundle bundleWithPath:@"/Library/PreferenceBundles/MImport.bundle"] pathForResource:@"dir" ofType:@"png"]] tag:1];
	UITabBarItem *tabBarItem3 = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemFavorites tag:2];
	[tabBarItem3 _setInternalTitle:[[NSUserDefaults standardUserDefaults] objectForKey:@"fav1_name"]?:@"Documents"];
	UITabBarItem *tabBarItem4 = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemFavorites tag:3];
	[tabBarItem4 _setInternalTitle:[[NSUserDefaults standardUserDefaults] objectForKey:@"fav2_name"]?:@"Downloads"];
	myTabBar.items = @[tabBarItem1, tabBarItem2, tabBarItem3, tabBarItem4];
	myTabBar.selectedItem = [myTabBar.items objectAtIndex:1];
	[self tabBar:myTabBar didSelectItem:myTabBar.selectedItem];
}
- (void)actionSheet:(UIActionSheet *)alert clickedButtonAtIndex:(NSInteger)button 
{
	if (button == [alert cancelButtonIndex]) {
		return;
	} else if(self.pathFav) {
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		[defaults setObject:self.pathFav forKey:button==0?@"fav1":@"fav2"];
		[defaults setObject:[self.pathFav lastPathComponent] forKey:button==0?@"fav1_name":@"fav2_name"];
		[defaults synchronize];
		[[MImportTapMenu sharedInstance] applyTabBarNavController:navCon];
	}
}
@end



%hook UINavigationBar
-(void)layoutSubviews
{
	%orig;
	BOOL hasButton = NO;
	for (UIBarButtonItem* now in self.topItem.rightBarButtonItems) {
		if (now.tag == 4) {
			hasButton = YES;
			break;
		}
	}
	
	[[MImportSwithServer sharedInstance] runThis];
	
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
	} else {
		return;
	}
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(launchMImportFromURL) object:receivedURLMImport];
	[self performSelector:@selector(launchMImportFromURL) withObject:receivedURLMImport afterDelay:1.5];
}
%new
- (void)launchMImportFromURL
{
	@try {
		if(!receivedURLMImport) {
			return;
		}
		
		if (access(mimport_running, F_OK) != 0) {
			if(open(mimport_running, O_CREAT)) {
			}
			usleep(1500000); //wait server start again.
		}
		
		MImportEditTagListController* NVBFromURL = [[%c(MImportEditTagListController) alloc] initWithPath:[receivedURLMImport copy]];
		NVBFromURL.isFromURL = YES;
		UINavigationController *navCon = [[UINavigationController alloc] initWithRootViewController:NVBFromURL];
		
		UIWindow *windows = [[UIApplication sharedApplication].delegate window];
		UIViewController *vc = windows.rootViewController;
		[vc presentViewController:navCon animated:YES completion:nil];	
	} @catch (NSException * e) {
	}	
}
%new
- (void)launchMImport
{
	@try {
		if (access(mimport_running, F_OK) != 0) {
			if(open(mimport_running, O_CREAT)) {
			}
			usleep(1500000); //wait server start again.
		}
		
		MImportDirBrowserController *dbtvc = [[[MImportDirBrowserController alloc] init] initWithStyle:UITableViewStyleGrouped];
		dbtvc.path = @"/";
		//UINavigationController *navCon = [[UINavigationController alloc] initWithRootViewController:dbtvc];
		
		if(!navCon) {
			navCon = [[UINavigationController alloc] initWithNavigationBarClass:[UINavigationBar class] toolbarClass:[UIToolbar class]];
		}
		[navCon setViewControllers:@[dbtvc] animated:NO];		
		
		[[MImportTapMenu sharedInstance] applyTabBarNavController:navCon];
		
		//UIWindow *windows = [[UIApplication sharedApplication].delegate window];
		//UIViewController *navC = windows.rootViewController;
		UIViewController* navC = (UINavigationController*)self.delegate;
		[navC presentViewController:navCon animated:YES completion:nil];	
	} @catch (NSException * e) {
	}	
}
%end




@implementation MImportEditTagListController
@synthesize path = _path;
@synthesize tags = _tags;
@synthesize isFromURL = _isFromURL;
- (void)importFileNow
{
	receivedURLMImport = nil;
	[self.view endEditing:YES];
	MImport_import([self.path copy], self.tags);
	if(self.isFromURL) {
		[self dismissViewControllerAnimated:YES completion:nil];
	} else {
		[self.navigationController popViewControllerAnimated:YES];
	}	
}
- (id)initWithPath:(NSString*)pat
{
	self = [super init];
	if (access(mimport_running, F_OK) != 0) {
		if(open(mimport_running, O_CREAT)) {
		}
		usleep(1500000); //wait server start again.
	}
	if(self) {
		self.path = pat;
		self.tags = [NSMutableDictionary dictionary];
		
		//__strong NSURL *audioFileURL = [NSURL fileURLWithPath:self.path];
		__strong NSURL *audioURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", kUrlServer, urlEncodeUsingEncoding(self.path)]];
		
		//AudioFileID fileID = nil;
		//AudioFileOpenURL((__bridge CFURLRef)audioURL, kAudioFileReadPermission, 0, &fileID);
		//CFDictionaryRef piDict = nil;
		//UInt32 piDataSize   = sizeof(piDict);
		//AudioFileGetProperty( fileID, kAudioFilePropertyInfoDictionary, &piDataSize, &piDict);
		//if(!piDict) {
		//	piDict = (__bridge CFDictionaryRef)[NSMutableDictionary dictionary];
		//}
		NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:audioURL];
		[request setHTTPMethod:@"POST"];
		request.cachePolicy = NSURLRequestReloadIgnoringLocalAndRemoteCacheData;
		NSError* error = nil;
		NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:&error];
		if(error) {
			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"MImport" 
						    message:[error description]
						    delegate:nil
						    cancelButtonTitle:@"OK" 
						    otherButtonTitles:nil];
			[alert show];
		}
		CFDictionaryRef piDict = (__bridge CFDictionaryRef)[[NSJSONSerialization JSONObjectWithData:data?:[NSData data] options:kNilOptions error:NULL] copy];
		
		NSMutableDictionary* metaDataParse = [NSMutableDictionary dictionary];
		NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:AVAssetReferenceRestrictionForbidNone], AVURLAssetReferenceRestrictionsKey, nil];
		AVAsset *asset = [AVURLAsset URLAssetWithURL:audioURL options:options];
		for (NSString *format in [asset availableMetadataFormats]) {
			for (AVMetadataItem *item in [asset metadataForFormat:format]) {
				if ([[item commonKey] isEqualToString:kTitle]) {
					[metaDataParse setObject:[item value] forKey:kTitle];
				}
				if ([[item commonKey] isEqualToString:kArtist]) {
					[metaDataParse setObject:[item value] forKey:kArtist];
				}
				if ([[item commonKey] isEqualToString:@"albumName"]) {
					[metaDataParse setObject:[item value] forKey:@"albumName"];
				}
				if ([[item commonKey] isEqualToString:kArtwork]) {
					if ([[item value] isKindOfClass:[NSDictionary class]]) {
						[metaDataParse setObject:[(NSDictionary *)[item value] objectForKey:@"data"] forKey:kArtwork];
					} else {
						[metaDataParse setObject:[item value] forKey:kArtwork];
					}
				}
			}
		}
		
		NSData* imageData = [metaDataParse objectForKey:kArtwork];
		
		if(!imageData) {
			NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString: [[[audioURL absoluteString] stringByDeletingPathExtension] stringByAppendingPathExtension:@"jpeg"] ]];
			request.cachePolicy = NSURLRequestReloadIgnoringLocalAndRemoteCacheData;
			imageData = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
			if(imageData) {
				if([imageData length] == 0) {
					imageData = nil;
				}
			}
			if(!imageData) {
				request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString: [[[audioURL absoluteString] stringByDeletingPathExtension] stringByAppendingPathExtension:@"jpg"] ]];
				request.cachePolicy = NSURLRequestReloadIgnoringLocalAndRemoteCacheData;
				imageData = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
			}
			if(imageData) {
				if([imageData length] == 0) {
					imageData = nil;
				}
			}
			if(!imageData) {
				request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString: [[[audioURL absoluteString] stringByDeletingPathExtension] stringByAppendingPathExtension:@"png"] ]];
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
		title     = [metaDataParse objectForKey:kTitle]?:[(__bridge NSDictionary *)piDict objectForKey:kTitle]?:[[self.path lastPathComponent] stringByDeletingPathExtension]?:@"Unknown Title";
		album     = [metaDataParse objectForKey:@"albumName"]?:[(__bridge NSDictionary *)piDict objectForKey:kAlbum]?:@"Unknown Album";
		artist    = [metaDataParse objectForKey:kArtist]?:[(__bridge NSDictionary *)piDict objectForKey:kArtist]?:@"Unknown Artist";
		genre     = [(__bridge NSDictionary *)piDict objectForKey:kGenre]?:@"";
		composer  = [(__bridge NSDictionary *)piDict objectForKey:kComposer]?:@"";
		
		int year = 2016;
		int trackNumber = 1;
		int trackCount = 1;
		int isExplicit = 0;
		int durationSecond = 0;
		
		durationSecond = [[(__bridge NSDictionary *)piDict objectForKey:kDuration]?:@(0) intValue];

		if(durationSecond == 0) {
			durationSecond = CMTimeGetSeconds(asset.duration);
		}
		
		if(id yearID = [(__bridge NSDictionary *)piDict objectForKey:kYear]) {
			if([yearID isKindOfClass:[NSString class]]) {
				if([(NSString*)yearID length] == 4) {
					year = [yearID intValue]; 
				} else if([(NSString*)yearID length] > 4) {
					yearID = [yearID substringToIndex:4];
					year = [yearID intValue]; 
				}
			}
		}
		if(id TrackID = [(__bridge NSDictionary *)piDict objectForKey:@"track number"]) {
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
		
		NSString *ext = [[self.path pathExtension] lowercaseString];
		int kindType = 1;
		if ([ext isEqualToString:@"mp4"] || [ext isEqualToString:@"m4v"] || [ext isEqualToString:@"mov"] || [ext isEqualToString:@"3gp"]) {
			kindType = 2;
		} else if ([ext isEqualToString:@"m4r"]) {
			kindType = 4;
		}
		[self.tags setObject:title forKey:kTitle];
		[self.tags setObject:album forKey:kAlbum];
		[self.tags setObject:artist forKey:kArtist];
		[self.tags setObject:genre forKey:kGenre];
		[self.tags setObject:composer forKey:kComposer];
		[self.tags setObject:@(year) forKey:kYear];
		[self.tags setObject:@(trackNumber) forKey:kTrackNumber];
		[self.tags setObject:@(durationSecond) forKey:kDuration];
		[self.tags setObject:@(trackCount) forKey:kTrackCount];
		[self.tags setObject:@(isExplicit) forKey:kExplicit];
		[self.tags setObject:@(kindType) forKey:kKindType];
		if(imageData != nil) {
			[self.tags setObject:imageData forKey:kArtwork];
		}		
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
	} else {
		[self.view setFrame:CGRectMake(self.view.frame.origin.x, self.view.frame.origin.y, self.view.frame.size.width, self.view.frame.size.height - 50)];
	}	
}
- (void)closeMImportEdit
{
	receivedURLMImport = nil;
	[self dismissViewControllerAnimated:YES completion:nil];
}
- (id)specifiers {
	if (!_specifiers) {
		NSMutableArray* specifiers = [NSMutableArray array];
		PSSpecifier* spec;
		
		spec = [PSSpecifier preferenceSpecifierNamed:[self.path lastPathComponent]
                                              target:self
                                                 set:NULL
                                                 get:NULL
                                              detail:Nil
                                                cell:PSStaticTextCell
                                                edit:Nil];
        [specifiers addObject:spec];
		
		spec = [PSSpecifier emptyGroupSpecifier];
        [specifiers addObject:spec];
		
		spec = [PSSpecifier preferenceSpecifierNamed:@"Fetch Tags Online Now"
                                              target:self
                                                 set:NULL
                                                 get:NULL
                                              detail:Nil
                                                cell:PSLinkCell
                                                edit:Nil];
		spec->action = @selector(getInfoNow);
		[spec setProperty:[NSNumber numberWithBool:TRUE] forKey:@"hasIcon"];
		[spec setProperty:[[UIImage alloc] initWithContentsOfFile:[[NSBundle bundleWithPath:@"/Library/PreferenceBundles/MImport.bundle"] pathForResource:@"icon" ofType:@"png"]] forKey:@"iconImage"];
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
		NSString *extensionType = [[self.path pathExtension] lowercaseString];
		if ([extensionType isEqualToString:@"m4a"] || [extensionType isEqualToString:@"m4r"]) {
			[spec setValues:@[@(1), @(2), @(3), @(4)] titles:@[@"Song", @"Video", @"TV episode", @"Ringtone"]];
		} else {
			[spec setValues:@[@(1), @(2), @(3)] titles:@[@"Song", @"Video", @"TV episode"]];
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
		if(NSData* dataArtWork = [self.tags objectForKey:kArtwork]) {
			[spec setProperty:[UIImage imageWithData:dataArtWork] forKey:@"iconImage"];
		} else {
			[spec setProperty:[[UIImage alloc] initWithContentsOfFile:[[NSBundle bundleWithPath:@"/Library/PreferenceBundles/MImport.bundle"] pathForResource:@"icon" ofType:@"png"]] forKey:@"iconImage"];
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
		
		spec = [PSSpecifier preferenceSpecifierNamed:@"Explicit"
                                                  target:self
											         set:@selector(setPreferenceValue:specifier:)
											         get:@selector(readPreferenceValue:)
                                                  detail:Nil
											        cell:PSSwitchCell
											        edit:Nil];
		[spec setProperty:kExplicit forKey:@"key"];
		[specifiers addObject:spec];
		
		spec = [PSSpecifier emptyGroupSpecifier];
        [spec setProperty:@"MImport © 2016 julioverne" forKey:@"footerText"];
        [specifiers addObject:spec];
		_specifiers = [specifiers copy];
	}
	return _specifiers;
}
- (void)getInfoNow
{
	[self.view endEditing:YES];
	__block UIProgressHUD* hud = [[UIProgressHUD alloc] init];
	[hud setText:@"Fetching..."];
	[hud showInView:self.view];
 	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		NSDictionary* responceInfo = getMusicInfo(@{
			kTitle:[self.tags objectForKey:kTitle]?[[self.tags objectForKey:kTitle] isEqualToString:@"Unknown Title"]?@"":[self.tags objectForKey:kTitle]:@"",
			kAlbum:[self.tags objectForKey:kAlbum]?[[self.tags objectForKey:kAlbum] isEqualToString:@"Unknown Album"]?@"":[self.tags objectForKey:kAlbum]:@"",
			kArtist:[self.tags objectForKey:kArtist]?[[self.tags objectForKey:kArtist] isEqualToString:@"Unknown Artist"]?@"":[self.tags objectForKey:kArtist]:@"",
			kDuration:[self.tags objectForKey:kDuration]?:@"",
		});
		//NSLog(@"*** responceInfo: %@", responceInfo);

		NSString* artworkURL = nil;
		if(NSString* artWork = [responceInfo objectForKey:@"album_coverart_800x800"]) {
			if([artWork length] > 0) {
				artworkURL = artWork;
			}
		} else if(NSString* artWork = [responceInfo objectForKey:@"album_coverart_500x500"]) {
			if([artWork length] > 0) {
				artworkURL = artWork;
			}
		} else if(NSString* artWork = [responceInfo objectForKey:@"album_coverart_350x350"]) {
			if([artWork length] > 0) {
				artworkURL = artWork;
			}
		} else if(NSString* artWork = [responceInfo objectForKey:@"album_coverart_100x100"]) {
			if([artWork length] > 0) {
				artworkURL = artWork;
			}
		}
		if(artworkURL) {
			if ([artworkURL rangeOfString:@"nocover.png"].location != NSNotFound) {
				artworkURL = nil;
			}
		}
		if(artworkURL) {
			NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:artworkURL]];
			request.cachePolicy = NSURLRequestReloadIgnoringLocalAndRemoteCacheData;
			NSError* error = nil;
			NSData* imageData = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:&error];
			if(imageData && !error) {
				UIImage *image = [UIImage imageWithData:imageData];
				[self.tags setObject:UIImageJPEGRepresentation(image, 1.0) forKey:kArtwork];
			}
		}
		if(NSString* track_name = [responceInfo objectForKey:@"track_name"]) {
			if([track_name length] > 0) {
				[self.tags setObject:track_name forKey:kTitle];
			}
		}
		if(NSString* album_name = [responceInfo objectForKey:@"album_name"]) {
			if([album_name length] > 0) {
				[self.tags setObject:album_name forKey:kAlbum];
			}
		}
		if(NSString* artist_name = [responceInfo objectForKey:@"artist_name"]) {
			if([artist_name length] > 0) {
				[self.tags setObject:artist_name forKey:kArtist];
			}
		}
		if(NSString* artist_name = [responceInfo objectForKey:@"artist_name"]) {
			if([artist_name length] > 0) {
				[self.tags setObject:artist_name forKey:kArtist];
			}
		}
		if(id explicitRes = [responceInfo objectForKey:@"explicit"]) {
			[self.tags setObject:@([explicitRes intValue]) forKey:kExplicit];
		}
		dispatch_async(dispatch_get_main_queue(), ^(void) {
			[hud hide];
			[self reloadSpecifiers];
		});
	});
} 
- (void)openLibrary
{
	UIImagePickerController *imagePickController = [[UIImagePickerController alloc] init];
    imagePickController.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    imagePickController.delegate = (id)self;
    imagePickController.allowsEditing = TRUE;
    [self presentModalViewController:imagePickController animated:YES];
}
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    UIImage *image = [info objectForKey:UIImagePickerControllerEditedImage];
    [self.tags setObject:UIImageJPEGRepresentation(image, 1.0) forKey:kArtwork];
    [self dismissModalViewControllerAnimated:YES];
	[self reloadSpecifiers];
}
- (void)viewDidLoad
{
	[super viewDidLoad];
	self.title = [[NSBundle bundleWithPath:@"/System/Library/Frameworks/UIKit.framework"] localizedStringForKey:@"Edit" value:@"Edit" table:nil];
	__strong UIBarButtonItem* kBTRight = [[UIBarButtonItem alloc] initWithTitle:[[NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/PhotoLibrary.framework"] localizedStringForKey:@"IMPORT" value:@"Import" table:@"PhotoLibrary"] style:UIBarButtonItemStylePlain target:self action:@selector(importFileNow)];
	kBTRight.tag = 4;
	self.navigationItem.rightBarButtonItem = kBTRight;
}
- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier
{
	[self.tags setObject:value forKey:[specifier identifier]];
}
- (id)readPreferenceValue:(PSSpecifier*)specifier
{
	return self.tags[[specifier identifier]];
}
- (void)_returnKeyPressed:(id)arg1
{
	[super _returnKeyPressed:arg1];
	[self.view endEditing:YES];
}
@end


@implementation MImportDirBrowserController
@synthesize path = _path, files = _files, selectedRows = _selectedRows, editRow = _editRow, contentDir = _contentDir;
- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
	if (access(mimport_running, F_OK) != 0) {
		if(open(mimport_running, O_CREAT)) {
		}
		usleep(1500000); //wait server start again.
	}
    if (self) {
		self.selectedRows = [NSMutableArray array];
    }
    return self;
}
- (void)importFile:(NSString*)path_file withMetadata:(NSDictionary*)metadataDic
{
	MImport_import(path_file, metadataDic);
}
- (NSString *)pathForFile:(NSString *)file
{
	return [self.path stringByAppendingPathComponent:file];
}
- (BOOL)fileIsDirectory:(NSString *)file
{
	//BOOL isdir = NO;
	//NSString *path = [self pathForFile:file];
	//[[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isdir];
	//return isdir;
	BOOL isDir = NO;
	if(id isDirValue = [[[self.contentDir objectForKey:@"content"] objectForKey:file] objectForKey:@"isDir"]) {
		isDir = [isDirValue boolValue];
	}	
	return isDir;
}
- (BOOL)extensionIsSupported:(NSString*)ext
{
	if([ext isEqualToString:@"mp3"] || // ok
	   [ext isEqualToString:@"aac"] || // ok
	   [ext isEqualToString:@"m4a"] || // ok
	   [ext isEqualToString:@"m4r"] || // ok
	   [ext isEqualToString:@"wav"] || // ok
	   [ext isEqualToString:@"aif"] || // ok
	   [ext isEqualToString:@"aiff"] || // ok
	   [ext isEqualToString:@"aifc"] || // ok
	   [ext isEqualToString:@"caf"] || // ok
	   [ext isEqualToString:@"amr"] || // ok
	   
	   [ext isEqualToString:@"mp4"] || // ok
	   [ext isEqualToString:@"m4v"] || // ok
	   [ext isEqualToString:@"mov"] || // ok
	   [ext isEqualToString:@"3gp"] // ok	   
	   ) {
		return YES;
	}
	return NO;
}
- (void)Refresh
{
	if (access(mimport_running, F_OK) != 0) {
		if(open(mimport_running, O_CREAT)) {
		}
		usleep(1500000); //wait server start again.
	}
	if (!self.path) {
		self.path = kPathWork;
	}
	NSMutableArray* tempFiles = [NSMutableArray array];
	NSError *error = nil;
	//self.files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.path error:&error]?:[NSArray array];
	__strong NSURL *pathURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", kUrlServer, urlEncodeUsingEncoding(self.path)]];
	//NSLog(@"**** pathURL: %@", pathURL);
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:pathURL];
	request.cachePolicy = NSURLRequestReloadIgnoringLocalAndRemoteCacheData;
	NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:&error];
	if(error) {
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"MImport" 
						    message:[error description]
						    delegate:nil
						    cancelButtonTitle:@"OK" 
						    otherButtonTitles:nil];
		[alert show];
	}
	NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data?:[NSData data] options:kNilOptions error:nil];  
	self.contentDir = [json copy];
	self.files = [[self.contentDir objectForKey:@"content"]?:[NSDictionary dictionary] allKeys];
	
	for(NSString*file in self.files) {
		BOOL isdir = [self fileIsDirectory:file];
		if(isdir) {
			[tempFiles addObject:file];
		} else {
			NSString *ext = [[file pathExtension] lowercaseString];
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
	[self.view setFrame:CGRectMake(self.view.frame.origin.x, self.view.frame.origin.y, self.view.frame.size.width, self.view.frame.size.height - 50)];
}
- (void)setRightButton
{
	__strong UIBarButtonItem * kBTRight;
	__strong UIBarButtonItem* kBTClose = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:self action:@selector(closeMImport)];
	if(self.editRow) {
		kBTRight = [[UIBarButtonItem alloc] initWithTitle:[[NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/PhotoLibrary.framework"] localizedStringForKey:@"IMPORT_SELECTED" value:@"Import Selected" table:@"PhotoLibrary"] style:UIBarButtonItemStylePlain target:self action:@selector(selectRow)];
		__strong UIBarButtonItem *kCancel = [[UIBarButtonItem alloc] initWithTitle:[[NSBundle bundleWithPath:@"/System/Library/Frameworks/UIKit.framework"] localizedStringForKey:@"Cancel" value:@"Cancel" table:nil] style:UIBarButtonItemStylePlain target:self action:@selector(cancelSelectRow)];
		kBTRight.tag = 4;
		kCancel.tag = 4;
		if([self.selectedRows count] > 0) {
			self.navigationItem.rightBarButtonItems = @[kBTClose, kBTRight, kCancel];
		} else {
			self.navigationItem.rightBarButtonItems = @[kBTClose, kCancel];
		}		
	} else {
		kBTRight = [[UIBarButtonItem alloc] initWithTitle:[[NSBundle bundleWithPath:@"/System/Library/Frameworks/UIKit.framework"] localizedStringForKey:@"Select" value:@"Select" table:nil] style:UIBarButtonItemStylePlain target:self action:@selector(selectRow)];
		kBTRight.tag = 4;
		self.navigationItem.rightBarButtonItems = @[kBTClose, kBTRight];
	}
	
}
- (void)viewDidLoad
{
	[super viewDidLoad];
	UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
	[refreshControl addTarget:self action:@selector(refreshView:) forControlEvents:UIControlEventValueChanged];
	[self.tableView addSubview:refreshControl];
	
	self.tableView.allowsMultipleSelection = YES;
	
	//[self.navigationController.navigationBar setBarTintColor:[UIColor colorWithRed:0.86 green:0.91 blue:1.00 alpha:1.0]];
	//[self.navigationController.navigationBar setTranslucent:NO];
	
	
	
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

/*- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *tableViewCell = [tableView cellForRowAtIndexPath:indexPath];	
    tableViewCell.accessoryType = UITableViewCellAccessoryNone;
	if ([self.selectedRows containsObject:@(indexPath.row)]) {
		[self.selectedRows removeObject:@(indexPath.row)];
	}
}*/

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
	if(!self.editRow) {
		for(id indexNowValue in self.selectedRows) {
			int indexNow = [indexNowValue intValue];
			NSString *file = [self.files objectAtIndex:indexNow];
			NSString *path = [self pathForFile:file];
			MImport_import([path copy], nil);
		}		
		[self cancelSelectRow];
		[self closeMImport];
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
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
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
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
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
    static __strong NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
		UILongPressGestureRecognizer *lpgr = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
		lpgr.minimumPressDuration = 0.8; //seconds
		lpgr.delegate = (id<UILongPressGestureRecognizerDelegate>)self;
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
	cell.textLabel.textColor = isLink&&isdir ? [UIColor blueColor] : [UIColor darkTextColor];
	cell.accessoryType = isdir ? UITableViewCellAccessoryDisclosureIndicator : [self.selectedRows containsObject:@(indexPath.row)]?UITableViewCellAccessoryCheckmark:UITableViewCellAccessoryNone;
	cell.imageView.image = isdir ? kIconFolder : nil;
	static __strong NSString* kKB = @"%.f KB";
	static __strong NSString* kMB = @"%.1f MB";
	cell.detailTextLabel.text = isdir ? nil : [NSString stringWithFormat:size>=1048576?kMB:kKB, size>=1048576?(float)size/1048576:(float)size/1024];
	if (!isdir) {
		NSString *ext = [[file pathExtension] lowercaseString];
		if ([self extensionIsSupported:ext]) {
			static __strong UIImage* kImageAudio;
			if(!kImageAudio) {
				kImageAudio = [[UIImage alloc] initWithContentsOfFile:[[NSBundle bundleWithPath:@"/Library/PreferenceBundles/MImport.bundle"] pathForResource:@"icon" ofType:@"png"]];
				if (kImageAudio && [kImageAudio respondsToSelector:@selector(imageWithRenderingMode:)]) {
					kImageAudio = [[kImageAudio imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] copy];
				} else {
					kImageAudio = [kImageAudio copy];
				}
			}
			cell.imageView.image = kImageAudio;
	    } else {
			//static __strong UIImage* kImageInstall = [[UIImage imageWithImage:[UIImage imageNamed:@"install.png"]] copy];
			cell.imageView.image = nil;
		}
	} else {
		static __strong UIImage* kImageDir;
		if(!kImageDir) {
			kImageDir = [[UIImage alloc] initWithContentsOfFile:[[NSBundle bundleWithPath:@"/Library/PreferenceBundles/MImport.bundle"] pathForResource:@"dir" ofType:@"png"]];
			if (kImageDir && [kImageDir respondsToSelector:@selector(imageWithRenderingMode:)]) {
				kImageDir = [[kImageDir imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] copy];
			} else {
				kImageDir = [kImageDir copy];
			}
		}
		cell.imageView.image = kImageDir;
	}
	
    return cell;
}
-(void)handleLongPress:(UILongPressGestureRecognizer *)gestureRecognizer
{
    CGPoint p = [gestureRecognizer locationInView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:p];
    if (indexPath != nil && gestureRecognizer.state == UIGestureRecognizerStateBegan) {
		[[MImportTapMenu sharedInstance] setPathFav:nil];
		NSString *file = [self.files objectAtIndex:indexPath.row];
		NSString *path = [self pathForFile:file];
		BOOL isdir = [self fileIsDirectory:file];
		if(isdir) {
			[[MImportTapMenu sharedInstance] setPathFav:path];
			UIActionSheet *popup = [[UIActionSheet alloc] initWithTitle:file delegate:[MImportTapMenu sharedInstance] cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
			[popup addButtonWithTitle:@"Set as Favorite 1"];
			[popup addButtonWithTitle:@"Set as Favorite 2"];
			[popup addButtonWithTitle:[[NSBundle bundleWithPath:@"/System/Library/Frameworks/UIKit.framework"] localizedStringForKey:@"Cancel" value:@"Cancel" table:nil]];
			[popup setCancelButtonIndex:[popup numberOfButtons] - 1];
			if (isDeviceIPad) {
				[popup showFromBarButtonItem:[[self navigationItem] rightBarButtonItem] animated:YES];
			} else {
				[popup showInView:self.view];
			}
		}
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
		UIActionSheet *popup = [[UIActionSheet alloc] initWithTitle:file delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
		[popup addButtonWithTitle:[[NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/PhotoLibrary.framework"] localizedStringForKey:@"IMPORT" value:@"Import" table:@"PhotoLibrary"]];
		[popup addButtonWithTitle:[[NSBundle bundleWithPath:@"/System/Library/Frameworks/UIKit.framework"] localizedStringForKey:@"Edit" value:@"Edit" table:nil]];
		[popup setDestructiveButtonIndex:[popup addButtonWithTitle:[[NSBundle bundleWithPath:@"/System/Library/Frameworks/UIKit.framework"] localizedStringForKey:@"Delete" value:@"Delete" table:nil]]];
		[popup addButtonWithTitle:[[NSBundle bundleWithPath:@"/System/Library/Frameworks/UIKit.framework"] localizedStringForKey:@"Cancel" value:@"Cancel" table:nil]];
		[popup setCancelButtonIndex:[popup numberOfButtons] - 1];
		popup.tag = indexPath.row;
		if (isDeviceIPad) {
			[popup showFromBarButtonItem:[[self navigationItem] rightBarButtonItem] animated:YES];
		} else {
			[popup showInView:self.view];
		}
	}
	return nil;
}
- (void)actionSheet:(UIActionSheet *)alert clickedButtonAtIndex:(NSInteger)button 
{
	NSString *file = [[self.files objectAtIndex:[alert tag]] copy];
	NSString *path = [[self pathForFile:file] copy];
	if (button == [alert cancelButtonIndex]) {
		return;
	}
	if  (button == 2) {
		CFOptionFlags result;
			CFUserNotificationDisplayAlert(
			0, //timeout
			kCFUserNotificationNoteAlertLevel, //icon
			NULL, //icon url
			NULL,
			NULL,
			(CFStringRef)@"MImport",
			(CFStringRef)[[path
			stringByAppendingString:@"\n"]
			stringByAppendingString:@"You want to remove this file?"],
			(CFStringRef)[[NSBundle mainBundle] localizedStringForKey:@"YES" value:@"" table:nil], //button options default to just "ok"
			(CFStringRef)[[NSBundle mainBundle] localizedStringForKey:@"NO" value:@"" table:nil],
			NULL,
			&result //response
			);			
			if (result == 0) {
				//unlink([self pathForFile:file].UTF8String);// remove file
				NSError* error = nil;
				BOOL success = [[NSFileManager defaultManager] removeItemAtPath:[self pathForFile:file] error:&error];
				if(error != nil) {
					UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"MImport" 
						    message:[error description]
						    delegate:nil
						    cancelButtonTitle:@"OK" 
						    otherButtonTitles:nil];
					[alert show];
				}
				if(success) {
					[self Refresh];
				}				
			}
		return;
	} else if  (button == 1) {
		NSString *ext = [[file pathExtension] lowercaseString];
		if ([self extensionIsSupported:ext]) {
			NSString *Url = [[self pathForFile:file] copy];
			@try {	
				[self.navigationController pushViewController:[[%c(MImportEditTagListController) alloc] initWithPath:Url] animated:YES];
			} @catch (NSException * e) {
			}
		} else {
			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"MImport" 
						    message:@"Unsupported file." 
						    delegate:self
						    cancelButtonTitle:@"OK" 
						    otherButtonTitles:nil];
			[alert show];
		}
		return;
	} else if  (button == 0) {
		NSString *ext = [[file pathExtension] lowercaseString];
		if ([self extensionIsSupported:ext]) {
			[self importFile:[[self pathForFile:file] copy] withMetadata:nil];
		} else {
			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"MImport" 
						    message:@"Unsupported file. Supportted files is: mp3, m4a" 
						    delegate:self
						    cancelButtonTitle:@"OK" 
						    otherButtonTitles:nil];
			[alert show];
		}
		return;
	}
	return;
}
@end

@implementation MImportSwithServer
+ (instancetype)sharedInstance
{
	static __strong id _shared;
	if(!_shared) {
		_shared = [[[self class] alloc] init];
		[[NSNotificationCenter defaultCenter] addObserver:_shared selector:@selector(appWillForegound:) name:UIApplicationWillEnterForegroundNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:_shared selector:@selector(appWillBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:_shared selector:@selector(appWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
	}
	return _shared;
}
- (void)appWillResignActive:(NSNotification*)note
{
	@autoreleasepool {
		if(open(mimport_running, O_CREAT)) {
		}
	}
}
- (void)appWillBackground:(NSNotification*)note
{
	@autoreleasepool {
		unlink(mimport_running);
	}
}
- (void)appWillForegound:(NSNotification*)note
{
	@autoreleasepool {
		if(open(mimport_running, O_CREAT)) {
		}
	}
}
- (void)runThis
{
	@autoreleasepool {
		UIApplicationState state = [[UIApplication sharedApplication] applicationState];
		if (!(state == UIApplicationStateBackground || state == UIApplicationStateInactive)) {
			if(open(mimport_running, O_CREAT)) {
			}
		}
	}
}
@end



%hook NSURL
-(id)scheme
{
	id ret = %orig;
	if(ret) {
		if([ret isEqualToString:@"music"] && [[self lastPathComponent] isEqualToString:@"mimport"]) {
			if(NSString* query = [self query]) {
				NSMutableDictionary *queryStringDictionary = [[NSMutableDictionary alloc] init];
				NSArray *urlComponents = [query componentsSeparatedByString:@"&"];
				for (NSString *keyValuePair in urlComponents) {
					NSArray *pairComponents = [keyValuePair componentsSeparatedByString:@"="];
					NSString *key = [[pairComponents firstObject] stringByRemovingPercentEncoding];
					NSString *value = [[pairComponents lastObject] stringByRemovingPercentEncoding];
					[queryStringDictionary setObject:value forKey:key];
				}
				if([queryStringDictionary objectForKey:@"path"] && (!receivedURLMImport || (receivedURLMImport && ![[queryStringDictionary objectForKey:@"path"] isEqualToString:receivedURLMImport]))) {
					needShowAgainMImportURL = YES;
					receivedURLMImport = [queryStringDictionary objectForKey:@"path"];
					//NSLog(@"***** DETECTED: %@", receivedURLMImport);
					//[[NSNotificationCenter defaultCenter] postNotificationName:@"com.julioverne.mimport/callback" object:nil];
					[[NSNotificationCenter defaultCenter] performSelector:@selector(postNotificationName:) withObject:@"com.julioverne.mimport/callback" afterDelay:0.5];
				}
			}
			ret = @"https";
		}
	}	
	return ret;
}
%end




/*__attribute__((constructor)) static void initialize_mimport()
{
	@autoreleasepool {
		UIApplicationState state = [[UIApplication sharedApplication] applicationState];
		if (!(state == UIApplicationStateBackground || state == UIApplicationStateInactive)) {
			if(open(mimport_running, O_CREAT)) {
			}
		}
	}
}*/
__attribute__((destructor)) static void finalize_mimport()
{
	@autoreleasepool {
		unlink(mimport_running);
	}
}