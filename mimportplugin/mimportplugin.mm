#import <notify.h>
#import <Social/Social.h>
#import <prefs.h>
#import <dlfcn.h>

#define NSLog(...)

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

@interface mimportpluginViewControllerShow : UIViewController  <NSExtensionRequestHandling>
@property(nonatomic,retain) NSExtensionContext* extensionContextNow;
@end

@implementation mimportpluginViewControllerShow
@synthesize extensionContextNow;
- (void)beginRequestWithExtensionContext:(NSExtensionContext *)context
{
	@try {
		extensionContextNow = context;
		NSExtensionItem *inputItem = context.inputItems.firstObject;
		NSItemProvider *provider = inputItem.attachments.firstObject;
		__block NSString* base64StringURL;
		base64StringURL = nil;
		for(NSString* providerTypeNow in provider.registeredTypeIdentifiers) {
			if(base64StringURL!=nil) {
				break;
			}
			__block BOOL waitForMe;
			waitForMe = NO;
			[provider loadItemForTypeIdentifier:providerTypeNow options:nil completionHandler:^(id<NSSecureCoding>url, NSError *error) {
				waitForMe = YES;
				NSLog(@"*** url: %@ \n error: %@", url, error);
				if(url && [(id)url isKindOfClass:[NSURL class]]) {
					if([(NSURL*)url isFileURL]) {
						NSString* origFile = [(NSURL*)url path];
						NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[origFile lastPathComponent]];
						@autoreleasepool {
							NSData *data = [[NSFileManager defaultManager] contentsAtPath:origFile];
							if(data) {
								[data writeToFile:filePath atomically:YES];
							}
						}
						if([[NSFileManager defaultManager] fileExistsAtPath:filePath isDirectory:nil]) {
							url = [NSURL fileURLWithPath:filePath];
						}
					}
					base64StringURL = encodeBase64WithData([[(NSURL*)url absoluteString] dataUsingEncoding:NSUTF8StringEncoding]);
					base64StringURL = [base64StringURL stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
					base64StringURL = [base64StringURL stringByReplacingOccurrencesOfString:@"+" withString:@"-"];
					base64StringURL = [base64StringURL stringByReplacingOccurrencesOfString:@"=" withString:@"."];
					if(base64StringURL) {
						[[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"music:///mimport?pathBase=%@", base64StringURL]]];
					}
				}
				waitForMe = NO;
			}];
			while(waitForMe) {
				sleep(1/4);
			}
			
		}	
	} @catch(NSException *e) {
	}	
}
- (void)viewWillAppear:(BOOL)arg1
{
	[super viewWillAppear:arg1];
	@try {
		[extensionContextNow completeRequestReturningItems:nil completionHandler:nil];
	} @catch(NSException *e) {
	}
}
@end


extern "C" int NSExtensionMain(int argc, char **argv);

int main(int argc, char **argv)
{	
	int ret = NSExtensionMain(argc, argv);
	return ret;
}
