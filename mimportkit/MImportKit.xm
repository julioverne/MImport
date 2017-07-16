#import "MImportKit.h"

static Class UIOpenWithAppActivityClassName;

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
	NSLog(@"*** fixURLRemoteOrLocalWithPath:\n inPath: %@ \n inPathRet: %@ \n retURL: %@", inPath, inPathRet, retURL);
	return retURL;
}

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
						NSLog(@"self.activityItems = %@", self.activityItems);
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
								} else if([now respondsToSelector:@selector(itemURL)]) {
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
							pathFileURL = fixURLRemoteOrLocalWithPath(pathFileItem);
						}
					} else if(pathFile && [pathFile respondsToSelector:@selector(itemURL)]) {
						pathFileURL = [(_UIDocumentActivityItemProvider*)pathFile itemURL];
					}
					
					if(!pathFileURL) {
						for(id now in self.activityItems) {
							if([now isKindOfClass:[NSURL class]]) {
								pathFileURL = now;
								break;
							} else if([now isKindOfClass:[NSString class]]) {
								pathFileURL = fixURLRemoteOrLocalWithPath(now);
								break;
							}
						}
					}
				}				
				if(pathFileURL && [pathFileURL isKindOfClass:[NSURL class]]) {
					NSString* base64StringURL = encodeBase64WithData([[pathFileURL absoluteString] dataUsingEncoding:NSUTF8StringEncoding]);
					base64StringURL = [base64StringURL stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
					base64StringURL = [base64StringURL stringByReplacingOccurrencesOfString:@"+" withString:@"-"];
					base64StringURL = [base64StringURL stringByReplacingOccurrencesOfString:@"=" withString:@"."];
					[[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"music:///mimport?pathBase=%@", base64StringURL]]];
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
	NSLog(@"*** initWithActivityItems: %@ \n applicationActivities: %@", arg1,arg2);
	
	//if(arg2) {
		@try {
			if(!arg2) {
				arg2 = [NSArray array];
			}
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
	//}
	return %orig(arg1, arg2);
}
%end
%end

%ctor
{
	UIOpenWithAppActivityClassName = objc_getClass("_UIOpenWithAppActivity")?:objc_getClass("_UIDocumentInteractionControllerOpenWithAppActivity");
	%init(MImportKit, UIOpenWithAppActivityClass = UIOpenWithAppActivityClassName);
}
