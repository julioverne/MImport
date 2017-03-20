#import "MImportKit.h"

Class UIOpenWithAppActivityClassName;

%group MImportKit
%hook UIOpenWithAppActivityClass
%property (assign) BOOL isMImport;
- (id)activityTitle
{
	if(((UIOpenWithAppActivityClass*)self).isMImport){
		return @"Import with MImport";
	} else {
		return %orig;
	}
}
- (BOOL)_canBeExcludedByActivityViewController:(id)arg1
{
	if(((UIOpenWithAppActivityClass*)self).isMImport){
		return NO;
	} else {
		return %orig;
	}
}
- (BOOL)canPerformWithActivityItems:(id)arg1
{
	if(((UIOpenWithAppActivityClass*)self).isMImport){
		return YES;
	} else {
		return %orig;
	}
}
%end
%hook UIActivityViewController
- (void)_performActivity:(UIOpenWithAppActivityClass *)arg1
{
	if(arg1) {
		@try{
		if([arg1 isKindOfClass:UIOpenWithAppActivityClassName]) {
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
		@try {
			if([arg2 isKindOfClass:[NSArray class]]) {
				NSMutableArray* mutRet = [arg2 mutableCopy];
				UIOpenWithAppActivityClass * actMimport = nil;
				if([[[UIOpenWithAppActivityClassName alloc] init] respondsToSelector:@selector(initWithApplicationIdentifier:documentInteractionController:)]) {
					actMimport = [[UIOpenWithAppActivityClassName alloc] initWithApplicationIdentifier:@"com.apple.Music" documentInteractionController:nil];
				} else {
					actMimport = [[UIOpenWithAppActivityClassName alloc] initWithApplicationIdentifier:@"com.apple.Music" documentInteractionController:nil appIsOwner:YES];
				}
				if(actMimport) {
					actMimport.isMImport = YES;
					[mutRet insertObject:actMimport atIndex:0];
					arg2 = mutRet;
				}
			}
		} @catch (NSException * e) {
		}
	}
	return %orig(arg1, arg2);
}
%end
%end

%ctor
{
	UIOpenWithAppActivityClassName = objc_getClass("_UIOpenWithAppActivity")?:objc_getClass("_UIDocumentInteractionControllerOpenWithAppActivity");
	%init(MImportKit, UIOpenWithAppActivityClass = UIOpenWithAppActivityClassName);
}
