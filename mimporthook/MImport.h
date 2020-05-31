#import <prefs.h>
#import <CommonCrypto/CommonCrypto.h>
#import <ifaddrs.h>
#import <arpa/inet.h>

enum {
  fileOperationNone             = 0,
  fileOperationDelete           = 1, 
  fileOperationMove             = 2,
  fileOperationExtract          = 3,
  fileOperationCopy             = 4,
};

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

#import "../MImportServerDefines.h"

#ifndef kCFCoreFoundationVersionNumber_iOS_13_0
#define kCFCoreFoundationVersionNumber_iOS_13_0 1665.15
#endif

#define is_iOS13 kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_13_0

extern char *__progname;
#define isDeviceIPad (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)

@interface UIImage (Private)
+ (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)bundleIdentifier format:(int)format scale:(CGFloat)scale;
@end

@interface UIProgressHUD : UIView
- (void) hide;
- (void) setText:(NSString*)text;
- (void) showInView:(UIView *)view;
@end

@interface LSApplicationProxy : NSObject
@property (nonatomic,readonly) NSDictionary * groupContainerURLs; // iOS 8 - 10.2
@property (nonatomic, readonly) NSString *applicationIdentifier;
@property (nonatomic, readonly) NSString *applicationType;
+ (id)applicationProxyForIdentifier:(id)arg1;
- (NSURL*)containerURL;
- (id)localizedName;
@end

@interface LSApplicationWorkspace : NSObject
+ (id)defaultWorkspace;
- (id)allInstalledApplications;
@end

@interface SSDownloadMetadata : NSObject
@property(retain) NSURL * primaryAssetURL;
@property bool shouldDownloadAutomatically;
- (id)initWithDictionary:(id)arg1;
@end

@interface SSDownloadQueue : NSObject
@property (nonatomic) bool shouldAutomaticallyFinishDownloads;
+ (id)mediaDownloadKinds;
+ (id)IPodDownloadKinds;
- (id)initWithDownloadKinds:(id)arg1;
- (BOOL)addDownload:(id)arg1;
@end

@interface SSDownloadManager : NSObject
+ (id)IPodDownloadManager;
- (void)addDownloads:(id)arg1 completionBlock:(id /* block */)arg2;
- (void)setDownloads:(id)arg1 completionBlock:(id /* block */)arg2;

- (void)_pauseDownloads:(id)arg1 forced:(bool)arg2 completionBlock:(id /* block */)arg3;
@end

@interface SSImportDownloadToIPodLibraryRequest : NSObject
- (id)initWithDownloadMetadata:(id)arg1;

- (bool)start;
- (void)startWithResponseBlock:(id /* block */)arg1;
@end


@interface SSDownload : NSObject

@property (nonatomic, retain) NSArray *assets;

- (id)initWithDownloadMetadata:(id)arg1;
-(void)setDownloadHandler:(id)arg1 completionBlock:(id)arg2 ;

- (void)pause;
- (void)restart;
- (void)resume;
@end


@interface MImportImportWithController : UITableViewController <UITableViewDelegate, UIActionSheetDelegate, UITabBarDelegate, UITabBarControllerDelegate>
@property (strong) NSArray *allUserApps;
@property (strong) NSArray *allSystemApps;
@property (strong) NSArray *allSharedGroup;
+ (id)shared;
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
@property (strong) UIProgressHUD* hud;
+ (id)shared;
@end

@interface MImportHistoryController : UITableViewController <UITableViewDelegate, UIActionSheetDelegate, UITabBarDelegate, UITabBarControllerDelegate> {
@private	
	NSArray *_allHistoryURLs;
}
@property (strong) NSArray *allHistoryURLs;
+ (id)shared;
@end


@interface MImportFavoriteController : UITableViewController <UITableViewDelegate, UIActionSheetDelegate, UITabBarDelegate, UITabBarControllerDelegate> {
@private	
	NSDictionary *_allFavURLs;
}
@property (strong) NSDictionary *allFavURLs;
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
@property (strong) UIProgressHUD* hud;
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

@interface MImportDropboxController : UITableViewController <UIWebViewDelegate, UIAlertViewDelegate, UITableViewDelegate, UITableViewDataSource, UIActionSheetDelegate, UITabBarDelegate, UITabBarControllerDelegate> {
@private
    UIWebView *webView;
	UIView* oldView;
	NSString *startURL;
	NSString *returnURL;
	NSString *access_token;
	NSString *pathDir;
	NSArray* contents;
}

@property (nonatomic, readonly) UIWebView *webView;
@property (nonatomic, retain) UIView *oldView;
@property (nonatomic, retain) NSArray* contents;
@property (nonatomic, retain) NSString *startURL;
@property (nonatomic, retain) NSString *returnURL;
@property (nonatomic, retain) NSString *access_token;
@property (nonatomic, retain) NSString *pathDir;
@property (nonatomic, readonly) UIActivityIndicatorView *loadingView;
@property (strong) UIProgressHUD* hud;
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
@property (assign) BOOL showConvertTool;
@property (strong) UIProgressHUD* hud;
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

@interface MImportUploadController : UITableViewController
+ (instancetype)sharedInstance;
@end

