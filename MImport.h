#define _Bool BOOL
#import "mimportsettings/prefs.h"

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

#define PORT_SERVER 7565

extern char *__progname;
#define isDeviceIPad (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)

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

@interface MImportDirBrowserController : UITableViewController <UITableViewDelegate, UIActionSheetDelegate> {
@private	
	NSString *_path;
	NSArray *_files;
	NSMutableArray *_selectedRows;
	BOOL _editRow;
	NSDictionary *_contentDir;
}
@property (strong) NSString *path;
@property (strong) NSArray *files;
@property (strong) NSMutableArray *selectedRows;
@property (assign) BOOL editRow;
@property (strong) NSDictionary *contentDir;

- (void)importFile:(NSString*)file withMetadata:(NSDictionary*)metadataDic;
@end

@interface MImportEditTagListController : PSListController <UIActionSheetDelegate, UIImagePickerControllerDelegate> {
@private	
	NSString *_path;
	NSMutableDictionary *_tags;
}
@property (strong) NSString *path;
@property (strong) NSMutableDictionary *tags;
- (id)initWithPath:(NSString*)pat;
- (void)importFileNow;
@end