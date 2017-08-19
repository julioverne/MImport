#define _Bool BOOL
#import <prefs.h>
#import <CommonCrypto/CommonCrypto.h>

#define NSLog(...)

// Media type keys
#define kIPIMediaSong		@"song"		// Song, music
#define kIPIMediaMusicVideo	@"music-video"	// Video
#define kIPIMediaPodcast	@"podcast"	// Podcast
#define kIPIMediaRingtone	@"ringtone"	// Ringtone
#define kIPIMediaSoftware	@"software"	// ??? AppStore application ???
#define kIPIMediaDocument	@"document"	// ???
#define kIPIMediaITunesU	@"itunes-u"	// iTunes U piece
#define kIPIMediaBook		@"book"		// Book
#define kIPIMediaEBook		@"ebook"	// E-Book
#define kIPIMediaTVEpisode	@"tv-episode"	// TV episode

#define PORT_SERVER 4194

extern char *__progname;
#define isDeviceIPad (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)

@interface UIImage (Private)
+ (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)bundleIdentifier format:(int)format scale:(CGFloat)scale;
@end


@interface LSApplicationProxy : NSObject
@property (nonatomic,readonly) NSDictionary * groupContainerURLs; // iOS 8 - 10.2
@property (nonatomic, readonly) NSString *applicationIdentifier;
+ (id)applicationProxyForIdentifier:(id)arg1;
- (NSURL*)containerURL;
- (NSURL*)boundContainerURL;
- (id)localizedName;
@end

@interface LSApplicationWorkspace : NSObject
+ (id)defaultWorkspace;
- (id)allInstalledApplications;
@end

@interface SSDownloadMetadata : NSObject
@property(retain) NSURL * primaryAssetURL;
- (id)initWithDictionary:(id)arg1;
@end

@interface SSDownloadQueue : NSObject
+ (id)mediaDownloadKinds;
- (id)initWithDownloadKinds:(id)arg1;
- (BOOL)addDownload:(id)arg1;
@end

@interface SSDownload : NSObject
- (id)initWithDownloadMetadata:(id)arg1;
-(void)setDownloadHandler:(id)arg1 completionBlock:(id)arg2 ;
@end


@interface MImportAppsController : UITableViewController <UITableViewDelegate, UIActionSheetDelegate, UITabBarDelegate, UITabBarControllerDelegate> {
@private	
	NSArray *_allUserApps;
	NSArray *_allSystemApps;
	NSArray *_allSharedGroup;
}
@property (strong) NSArray *allUserApps;
@property (strong) NSArray *allSystemApps;
@property (strong) NSArray *allSharedGroup;
+ (id)shared;
@end

@interface MImportDirBrowserController : UITableViewController <UITableViewDelegate, UIActionSheetDelegate, UITabBarDelegate, UITabBarControllerDelegate> {
@private	
	NSString *_path;
	NSArray *_files;
	NSMutableArray *_selectedRows;
	BOOL _editRow;
	NSDictionary *_contentDir;
	UIImage *_kImageAudio;
}
@property (strong) NSString *path;
@property (strong) NSArray *files;
@property (strong) NSMutableArray *selectedRows;
@property (assign) BOOL editRow;
@property (strong) NSDictionary *contentDir;
@property (strong) UIImage *kImageAudio;
@end

@interface UIActionSheet ()
- (NSString *) context;
- (void) setContext:(NSString *)context;
@end

@interface UITextField (Apple)
- (UITextField *) textInputTraits;
@end

@interface UIAlertView (Apple)
- (void) addTextFieldWithValue:(NSString *)value label:(NSString *)label;
- (id) buttons;
- (NSString *) context;
- (void) setContext:(NSString *)context;
- (void) setNumberOfRows:(int)rows;
- (void) setRunsModal:(BOOL)modal;
- (UITextField *) textField;
- (UITextField *) textFieldAtIndex:(NSUInteger)index;
- (void) _updateFrameForDisplay;
@end

@interface MImportEditTagListController : PSListController <UIActionSheetDelegate, UIImagePickerControllerDelegate> {
@private	
	NSURL *_sourceURL;
	NSMutableDictionary *_tags;
	BOOL _isFromURL;
}
@property (strong) NSURL *sourceURL;
@property (strong) NSMutableDictionary *tags;
@property (assign) BOOL isFromURL;
- (id)initWithURL:(NSURL*)inURL;
- (void)importFileNow;
@end

@interface CellInfoApp : NSObject
@property (strong) NSURL *sourceURL;
@property (strong) UIImage *icon;
@property (strong) NSString *name;
@property (strong) NSString *info;
@property (strong) NSString *bundleId;
@end
