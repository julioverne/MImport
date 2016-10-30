#import "MImportKit.h"

@interface _UIDocumentActivityItemProvider : NSObject
@property (nonatomic, copy) _UIDocumentActivityItemProvider *asset;
- (id)item;
- (id)mainFileURL;
- (id)mediaPath; //NSString
@end
@interface _UIOpenWithAppActivity : UIActivity
@property (assign) BOOL isMImport;
- (id)initWithApplicationIdentifier:(id)arg1 documentInteractionController:(id)arg2;
@end
@interface UIActivityViewController (gg)
@property (nonatomic, copy) NSArray *activityItems;
@end

%hook _UIOpenWithAppActivity
%property (assign) BOOL isMImport;
- (id)activityTitle
{
	if(self.isMImport){
		return @"Import with MImport";
	} else {
		return %orig;
	}
}
- (BOOL)_canBeExcludedByActivityViewController:(id)arg1
{
	if(self.isMImport){
		return NO;
	} else {
		return %orig;
	}
}
- (BOOL)canPerformWithActivityItems:(id)arg1
{
	if(self.isMImport){
		return YES;
	} else {
		return %orig;
	}
}
%end

%hook UIActivityViewController
- (void)_performActivity:(_UIOpenWithAppActivity *)arg1
{
	if(arg1) {
		@try{
		if([arg1 isKindOfClass:%c(_UIOpenWithAppActivity)]) {
			if(arg1.isMImport) {
				NSURL* pathFileURL = nil;
				if([self respondsToSelector:@selector(activityItems)]) {
					id pathFile = nil;
					if(self.activityItems) {
						for(id now in self.activityItems) {
							if(now) {
								pathFile = now;
								if([now isKindOfClass:[NSURL class]]) {
									break;
								} else if([now respondsToSelector:@selector(item)]) {
									break;
								} else if([now respondsToSelector:@selector(asset)]) {
									break;
								} else if([now respondsToSelector:@selector(mediaPath)]) {
									break;
								}
							}
						}
					}
					if(pathFile && [pathFile isKindOfClass:[NSURL class]]) {
						pathFileURL = pathFile;
					} else if(pathFile && [pathFile respondsToSelector:@selector(item)]) {
						NSURL* pathFileItem = [(_UIDocumentActivityItemProvider*)pathFile item];
						if(pathFileItem && [pathFileItem isKindOfClass:[NSURL class]]) {
							pathFileURL = pathFileItem;
						}
					} else if(pathFile && [pathFile respondsToSelector:@selector(asset)]) {
						_UIDocumentActivityItemProvider* assetItem = [(_UIDocumentActivityItemProvider*)pathFile asset];
						if(assetItem && [assetItem respondsToSelector:@selector(mainFileURL)]) {
							NSURL* pathFileItem = [assetItem mainFileURL];
							if(pathFileItem && [pathFileItem isKindOfClass:[NSURL class]]) {
								pathFileURL = pathFileItem;
							}
						}
					} else if(pathFile && [pathFile respondsToSelector:@selector(mediaPath)]) {
						NSString* pathFileItem = [(_UIDocumentActivityItemProvider*)pathFile mediaPath];
						if(pathFileItem && [pathFileItem isKindOfClass:[NSString class]]) {
							pathFileURL = [NSURL fileURLWithPath:pathFileItem];
						}
					}		
				}					
				if(pathFileURL && [pathFileURL isKindOfClass:[NSURL class]]) {
					[[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"music:///mimport?path=%@", [[pathFileURL absoluteString] stringByReplacingOccurrencesOfString:@"file://" withString:@""]]]];
				}
				%orig(nil);
				return;
			}
		}
		} @catch (NSException * e) {
		}
	}
	%orig;
}
- (id)initWithActivityItems:(id)arg1 applicationActivities:(id)arg2
{
	if(arg2) {
		@try{
		if([arg2 isKindOfClass:[NSArray class]]) {
			NSMutableArray* mutRet = [arg2 mutableCopy];
			_UIOpenWithAppActivity * actMimport = [[%c(_UIOpenWithAppActivity) alloc] initWithApplicationIdentifier:@"com.apple.Music" documentInteractionController:nil];
			actMimport.isMImport = YES;
			[mutRet insertObject:actMimport atIndex:0];
			arg2 = mutRet;
		}
		} @catch (NSException * e) {
		}
	}	
	id ret = %orig;
	return ret;
}
%end


