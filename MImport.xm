#include <mach-o/dyld.h>
#import <dlfcn.h>
#import <substrate.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreFoundation/CFUserNotification.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

#import "MImport.h"


@implementation NSString (MImport)
-(NSString *)urlEncodeUsingEncoding:(NSStringEncoding)encoding
{
	static __strong NSString* kCodes = @"!*'\"();@&=+$,?%#[]% ";
	return (NSString*)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)self, NULL, (CFStringRef)kCodes, CFStringConvertNSStringEncodingToEncoding(encoding));
}
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

void MImport_import(NSString *mediaPath, NSDictionary *mediaInfo)
{
	@autoreleasepool {
	if(!mediaPath) {
		return;
	}
	if(!mediaInfo) {
		mediaInfo = [NSDictionary dictionary];
	}
	
	__strong NSURL *audioURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", [NSString stringWithFormat:[@"http://%@:%i/" substringToIndex:12], @"localhost", PORT_SERVER], [mediaPath urlEncodeUsingEncoding:NSUTF8StringEncoding]]];
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
	NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:NULL];
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
	
	durationSecond = [[(__bridge NSDictionary *)piDict objectForKey:@"approximate duration in seconds"]?:@(0) intValue];
	
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
	
	
	NSString* artworkURLString = [NSString stringWithFormat:@"%@%@:%@%@", @"http://", [audioURL host], [audioURL port], [ap/*[[[audioURL path] stringByDeletingPathExtension] stringByAppendingPathExtension:@"jpeg"]*/ urlEncodeUsingEncoding:NSUTF8StringEncoding]];
	
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
	        @"compilation": @(0),
	         //@"composerId": @(327699389),
	        @"composerName": composer,
	        @"copyright": copyright,
	         //@"discCount": @(1),
	         //@"discNumber": @(1),
	        @"drmVersionNumber": @(0),
	        @"duration": @(durationSecond * 1000),
	        @"explicit": @(isExplicit),
	        @"fileExtension": ext,
	        @"gapless": @(0),
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
		__strong UIBarButtonItem* kBTLaunch = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemOrganize target:self action:@selector(launchMImport)];
		kBTLaunch.tag = 4;
		__autoreleasing NSMutableArray* BT = [self.topItem.rightBarButtonItems?:[NSArray array] mutableCopy];
		[BT addObject:kBTLaunch];	
		self.topItem.rightBarButtonItems = [BT copy];
	}
}
%new
- (void)launchMImport
{
	@try {
		if(open(mimport_running, O_CREAT)) {
		}
		UINavigationController* navC = (UINavigationController*)self.delegate;
		UINavigationController *navCon = [[UINavigationController alloc] initWithRootViewController:[[[%c(MImportDirBrowserController) alloc] init] initWithStyle:UITableViewStyleGrouped]];
		[navC presentViewController:navCon animated:YES completion:nil];	
	} @catch (NSException * e) {
	}	
}
%end




@implementation MImportEditTagListController
@synthesize path = _path;
@synthesize tags = _tags;
- (void)importFileNow
{
	[self.view endEditing:YES];
	MImport_import([self.path copy], self.tags);
	[self.navigationController popViewControllerAnimated:YES];
}
- (id)initWithPath:(NSString*)pat
{
	self = [super init];
	if(self) {
		self.path = pat;
		self.tags = [NSMutableDictionary dictionary];
		
		//__strong NSURL *audioFileURL = [NSURL fileURLWithPath:self.path];
		__strong NSURL *audioURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", [NSString stringWithFormat:[@"http://%@:%i/" substringToIndex:12], @"localhost", PORT_SERVER], [self.path urlEncodeUsingEncoding:NSUTF8StringEncoding]]];
		
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
		NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:NULL];
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
		[self.tags setObject:@(trackCount) forKey:kTrackCount];
		[self.tags setObject:@(isExplicit) forKey:kExplicit];
		[self.tags setObject:@(kindType) forKey:kKindType];
		if(imageData != nil) {
			[self.tags setObject:imageData forKey:kArtwork];
		}		
	}
	return self;
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
	if (!self.path) {
		self.path = kPathWork;
	}
	NSMutableArray* tempFiles = [NSMutableArray array];
	NSError *error = nil;
	//self.files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.path error:&error]?:[NSArray array];
	__strong NSURL *pathURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", [NSString stringWithFormat:[@"http://%@:%i/" substringToIndex:12], @"localhost", PORT_SERVER], [self.path urlEncodeUsingEncoding:NSUTF8StringEncoding]]];
	//NSLog(@"**** pathURL: %@", pathURL);
	NSURLRequest *request = [NSURLRequest requestWithURL:pathURL];
	NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:&error];
	NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data?:[NSData data] options:kNilOptions error:&error];  
	self.contentDir = [json copy];
	self.files = [[self.contentDir objectForKey:@"content"]?:[NSDictionary dictionary] allKeys];
	
	
	
	if(error != nil) {
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"MImport" 
						    message:[error description]
						    delegate:nil
						    cancelButtonTitle:@"OK" 
						    otherButtonTitles:nil];
		[alert show];
	}
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
}
- (void)setRightButton
{
	__strong UIBarButtonItem * kBTRight;
	if(self.editRow) {
		kBTRight = [[UIBarButtonItem alloc] initWithTitle:[[NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/PhotoLibrary.framework"] localizedStringForKey:@"IMPORT_SELECTED" value:@"Import Selected" table:@"PhotoLibrary"] style:UIBarButtonItemStylePlain target:self action:@selector(selectRow)];
		__strong UIBarButtonItem *kCancel = [[UIBarButtonItem alloc] initWithTitle:[[NSBundle bundleWithPath:@"/System/Library/Frameworks/UIKit.framework"] localizedStringForKey:@"Cancel" value:@"Cancel" table:nil] style:UIBarButtonItemStylePlain target:self action:@selector(cancelSelectRow)];
		kBTRight.tag = 4;
		kCancel.tag = 4;
		if([self.selectedRows count] > 0) {
			self.navigationItem.rightBarButtonItems = @[kBTRight, kCancel];
		} else {
			self.navigationItem.rightBarButtonItems = @[kCancel];
		}		
	} else {
		kBTRight = [[UIBarButtonItem alloc] initWithTitle:[[NSBundle bundleWithPath:@"/System/Library/Frameworks/UIKit.framework"] localizedStringForKey:@"Select" value:@"Select" table:nil] style:UIBarButtonItemStylePlain target:self action:@selector(selectRow)];
		kBTRight.tag = 4;
		self.navigationItem.rightBarButtonItems = @[kBTRight];
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
	//__strong UIBarButtonItem* kBTRight = [[UIBarButtonItem alloc] init];
	//kBTRight.tag = 4;
	//self.navigationItem.rightBarButtonItem = kBTRight;
	
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