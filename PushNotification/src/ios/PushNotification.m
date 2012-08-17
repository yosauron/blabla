//
//  PushNotification.m
//
// Based on the Push Notifications Cordova Plugin by Olivier Louvignes on 06/05/12.
// Modified by Max Konev on 18/05/12.
//
// Pushwoosh Push Notifications Plugin for Cordova iOS
// www.pushwoosh.com
//
// MIT Licensed

#import "PushNotification.h"
#import <Cordova/JSONKit.h>

#import "AppDelegate.h"
#import <objc/runtime.h>

@interface AppDelegate(PushNotifications)
- (void)application:(UIApplication *)app didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)devToken;
- (void)application:(UIApplication *)app didFailToRegisterForRemoteNotificationsWithError:(NSError *)err;
- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo;

- (BOOL)application:(UIApplication*)application newDidFinishLaunchingWithOptions:(NSDictionary*)launchOptions;
@end

@implementation AppDelegate(PushNotifications)

- (BOOL) application:(UIApplication*)application newDidFinishLaunchingWithOptions:(NSDictionary*)launchOptions {
	BOOL result = [self application:application newDidFinishLaunchingWithOptions:launchOptions];

	PushNotification *pushHandler = [self.viewController getCommandInstance:@"PushNotification"];
	if(!pushHandler || !pushHandler.pushManager)
		return result;

	if(result) {
		NSDictionary * userInfo = [launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];	
		[pushHandler.pushManager handlePushReceived:userInfo];

		
		NSString* u = [userInfo objectForKey:@"u"];
		if (u) {
			NSDictionary *dict = [u objectFromJSONString];
			if (dict) {
				NSMutableDictionary *pn = [NSMutableDictionary dictionaryWithDictionary:userInfo];
				[pn setObject:dict forKey:@"u"];
				userInfo = pn;
			}
		}

		if(userInfo) {
			NSString *jsonString = [userInfo JSONString];
			//the webview is not loaded yet, keep it for the callback
			pushHandler.startPushData = jsonString;
		}
	}
	
	return result;
}

+ (void)load {
	method_exchangeImplementations(class_getInstanceMethod(self, @selector(application:didFinishLaunchingWithOptions:)), class_getInstanceMethod(self, @selector(application:newDidFinishLaunchingWithOptions:)));	
}

- (void)application:(UIApplication *)app didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)devToken {
	
	PushNotification *pushHandler = [self.viewController getCommandInstance:@"PushNotification"];
	[pushHandler.pushManager handlePushRegistration:devToken];
	
    //you might want to send it to your backend if you use remote integration
	NSString *token = [pushHandler.pushManager getPushToken];
	NSLog(@"Push token: %@", token);
	
	[pushHandler didRegisterForRemoteNotificationsWithDeviceToken:token];
}

- (void)application:(UIApplication *)app didFailToRegisterForRemoteNotificationsWithError:(NSError *)err {
	PushNotification* pushHandler = [self.viewController getCommandInstance:@"PushNotification"];
	[pushHandler didFailToRegisterForRemoteNotificationsWithError:err];
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
	PushNotification *pushHandler = [self.viewController getCommandInstance:@"PushNotification"];
	[pushHandler.pushManager handlePushReceived:userInfo];
}
@end

@implementation PushNotification

@synthesize callbackIds = _callbackIds;
@synthesize pushManager, startPushData;

- (NSMutableDictionary*)callbackIds {
	if(_callbackIds == nil) {
		_callbackIds = [[NSMutableDictionary alloc] init];
	}
	return _callbackIds;
}
- (PushNotificationManager*)pushManager {
	if(pushManager == nil) {
		AppDelegate * delegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
		UIViewController * mainVC = delegate.viewController;
		
		NSString * appid = [[NSUserDefaults standardUserDefaults] objectForKey:@"Pushwoosh_APPID"];
		
		if(!appid)
			return nil;
		
		NSString * appname = [[NSUserDefaults standardUserDefaults] objectForKey:@"Pushwoosh_APPNAME"];
		if(!appname)
			appname = @"";
			
		pushManager = [[PushNotificationManager alloc] initWithApplicationCode:appid navController:mainVC appName:appname ];
		pushManager.delegate = self;
	}
	return pushManager;
}

- (void)onDeviceReady:(NSMutableArray *)arguments withDict:(NSMutableDictionary*)options {
	AppDelegate *delegate = [[UIApplication sharedApplication] delegate];
	PushNotification *pushHandler = [delegate.viewController getCommandInstance:@"PushNotification"];
	if(pushHandler.startPushData) {
		NSString *jsStatement = [NSString stringWithFormat:@"window.plugins.pushNotification.notificationCallback(%@);", pushHandler.startPushData];
		[pushHandler writeJavascript:[NSString stringWithFormat:@"setTimeout(function() { %@; }, 0);", jsStatement]];
		pushHandler.startPushData = nil;
	}
}

- (void)registerDevice:(NSMutableArray *)arguments withDict:(NSMutableDictionary *)options {

	// The first argument in the arguments parameter is the callbackID.
	[self.callbackIds setValue:[arguments pop] forKey:@"registerDevice"];

	UIRemoteNotificationType notificationTypes = UIRemoteNotificationTypeNone;
	if ([options objectForKey:@"badge"]) {
		notificationTypes |= UIRemoteNotificationTypeBadge;
	}
	if ([options objectForKey:@"sound"]) {
		notificationTypes |= UIRemoteNotificationTypeSound;
	}
	if ([options objectForKey:@"alert"]) {
		notificationTypes |= UIRemoteNotificationTypeAlert;
	}

	if (notificationTypes == UIRemoteNotificationTypeNone)
		NSLog(@"PushNotification.registerDevice: Push notification type is set to none");
	
	NSString *appid = [options objectForKey:@"appid"];
	NSString *appname = [options objectForKey:@"appname"];
	
	if(!appid) {
		NSLog(@"PushNotification.registerDevice: Missing Pushwoosh App ID");
		return;
	}
	
	[[NSUserDefaults standardUserDefaults] setObject:appid forKey:@"Pushwoosh_APPID"];
	if(appname) {
		[[NSUserDefaults standardUserDefaults] setObject:appname forKey:@"Pushwoosh_APPNAME"];
	}
	
	//[[UIApplication sharedApplication] unregisterForRemoteNotifications];
	[[UIApplication sharedApplication] registerForRemoteNotificationTypes:notificationTypes];

}

- (void)didRegisterForRemoteNotificationsWithDeviceToken:(NSString *)token {

    NSMutableDictionary *results = [PushNotification getRemoteNotificationStatus];
    [results setValue:token forKey:@"deviceToken"];

	CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:results];
	[self writeJavascript:[pluginResult toSuccessCallbackString:[self.callbackIds valueForKey:@"registerDevice"]]];
}

- (void)didFailToRegisterForRemoteNotificationsWithError:(NSError*)error {

	NSMutableDictionary *results = [NSMutableDictionary dictionary];
	[results setValue:[NSString stringWithFormat:@"%@", error] forKey:@"error"];

	CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:results];
	[self writeJavascript:[pluginResult toErrorCallbackString:[self.callbackIds valueForKey:@"registerDevice"]]];
}


- (void) onPushAccepted:(PushNotificationManager *)manager withNotification:(NSDictionary *)pushNotification{
	//reset badge counter
	[[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
	
	NSString* u = [pushNotification objectForKey:@"u"];
	if (u) {
		NSDictionary *dict = [u objectFromJSONString];
		if (dict) {
			NSMutableDictionary *pn = [NSMutableDictionary dictionaryWithDictionary:pushNotification];
			[pn setObject:dict forKey:@"u"];
			pushNotification = pn;
		}
	}
	
	NSString *jsonString = [pushNotification JSONString];
	NSString *jsStatement = [NSString stringWithFormat:@"window.plugins.pushNotification.notificationCallback(%@);", jsonString];
	[self writeJavascript:[NSString stringWithFormat:@"setTimeout(function() { %@; }, 0);", jsStatement]];
}

+ (NSMutableDictionary*)getRemoteNotificationStatus {

    NSMutableDictionary *results = [NSMutableDictionary dictionary];

    NSUInteger type = 0;
    // Set the defaults to disabled unless we find otherwise...
    NSString *pushBadge = @"0";
    NSString *pushAlert = @"0";
    NSString *pushSound = @"0";

#if !TARGET_IPHONE_SIMULATOR

    // Check what Notifications the user has turned on.  We registered for all three, but they may have manually disabled some or all of them.
    type = [[UIApplication sharedApplication] enabledRemoteNotificationTypes];

    // Check what Registered Types are turned on. This is a bit tricky since if two are enabled, and one is off, it will return a number 2... not telling you which
    // one is actually disabled. So we are literally checking to see if rnTypes matches what is turned on, instead of by number. The "tricky" part is that the
    // single notification types will only match if they are the ONLY one enabled.  Likewise, when we are checking for a pair of notifications, it will only be
    // true if those two notifications are on.  This is why the code is written this way
    if(type == UIRemoteNotificationTypeBadge){
        pushBadge = @"1";
    }
    else if(type == UIRemoteNotificationTypeAlert) {
        pushAlert = @"1";
    }
    else if(type == UIRemoteNotificationTypeSound) {
        pushSound = @"1";
    }
    else if(type == ( UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeAlert)) {
        pushBadge = @"1";
        pushAlert = @"1";
    }
    else if(type == ( UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound)) {
        pushBadge = @"1";
        pushSound = @"1";
    }
    else if(type == ( UIRemoteNotificationTypeAlert | UIRemoteNotificationTypeSound)) {
        pushAlert = @"1";
        pushSound = @"1";
    }
    else if(type == ( UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeAlert | UIRemoteNotificationTypeSound)) {
        pushBadge = @"1";
        pushAlert = @"1";
        pushSound = @"1";
    }

#endif

    // Affect results
    [results setValue:[NSString stringWithFormat:@"%d", type] forKey:@"type"];
	[results setValue:[NSString stringWithFormat:@"%d", type != UIRemoteNotificationTypeNone] forKey:@"enabled"];
    [results setValue:pushBadge forKey:@"pushBadge"];
    [results setValue:pushAlert forKey:@"pushAlert"];
    [results setValue:pushSound forKey:@"pushSound"];

    return results;

}

- (void)getRemoteNotificationStatus:(NSMutableArray *)arguments withDict:(NSMutableDictionary *)options {

	// The first argument in the arguments parameter is the callbackID.
	[self.callbackIds setValue:[arguments pop] forKey:@"getRemoteNotificationStatus"];

	NSMutableDictionary *results = [PushNotification getRemoteNotificationStatus];

	CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:results];
	[self writeJavascript:[pluginResult toSuccessCallbackString:[self.callbackIds valueForKey:@"getRemoteNotificationStatus"]]];
}

- (void)setApplicationIconBadgeNumber:(NSMutableArray *)arguments withDict:(NSMutableDictionary *)options {

	// The first argument in the arguments parameter is the callbackID.
	[self.callbackIds setValue:[arguments pop] forKey:@"setApplicationIconBadgeNumber"];

    int badge = [[options objectForKey:@"badge"] intValue] ?: 0;
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:badge];

    NSMutableDictionary *results = [NSMutableDictionary dictionary];
	[results setValue:[NSNumber numberWithInt:badge] forKey:@"badge"];
    [results setValue:[NSNumber numberWithInt:1] forKey:@"success"];

	CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:results];
	[self writeJavascript:[pluginResult toSuccessCallbackString:[self.callbackIds valueForKey:@"setApplicationIconBadgeNumber"]]];
}

- (void)cancelAllLocalNotifications:(NSMutableArray *)arguments withDict:(NSMutableDictionary *)options {

	// The first argument in the arguments parameter is the callbackID.
	[self.callbackIds setValue:[arguments pop] forKey:@"cancelAllLocalNotifications"];
	
	[[UIApplication sharedApplication] cancelAllLocalNotifications];
	
	CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
	[self writeJavascript:[pluginResult toSuccessCallbackString:[self.callbackIds valueForKey:@"cancelAllLocalNotifications"]]];
}

- (void) dealloc {
	self.pushManager = nil;
	self.startPushData = nil;

	[_callbackIds dealloc];
	[super dealloc];
}

@end


////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Pushwoosh SDK

//Pushwoosh SDK
#include <sys/socket.h> // Per msqr
#include <sys/sysctl.h>
#include <net/if.h>
#include <net/if_dl.h>
#import <CommonCrypto/CommonDigest.h>


#define kServicePushNotificationUrl @"https://cp.pushwoosh.com/json/1.2/registerDevice"
#define kServiceHtmlContentFormatUrl @"https://cp.pushwoosh.com/content/%@"

@implementation PushNotificationManager

@synthesize appCode, appName, navController, pushNotifications, delegate;
@synthesize supportedOrientations;

- (NSString *) stringFromMD5: (NSString *)val{
    
    if(val == nil || [val length] == 0)
        return nil;
    
    const char *value = [val UTF8String];
    
    unsigned char outputBuffer[CC_MD5_DIGEST_LENGTH];
    CC_MD5(value, strlen(value), outputBuffer);
    
    NSMutableString *outputString = [[NSMutableString alloc] initWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for(NSInteger count = 0; count < CC_MD5_DIGEST_LENGTH; count++){
        [outputString appendFormat:@"%02x",outputBuffer[count]];
    }
    
    return [outputString autorelease];
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Private Methods

// Return the local MAC addy
// Courtesy of FreeBSD hackers email list
// Accidentally munged during previous update. Fixed thanks to erica sadun & mlamb.
- (NSString *) macaddress{
    
    int                 mib[6];
    size_t              len;
    char                *buf;
    unsigned char       *ptr;
    struct if_msghdr    *ifm;
    struct sockaddr_dl  *sdl;
    
    mib[0] = CTL_NET;
    mib[1] = AF_ROUTE;
    mib[2] = 0;
    mib[3] = AF_LINK;
    mib[4] = NET_RT_IFLIST;
    
    if ((mib[5] = if_nametoindex("en0")) == 0) {
        printf("Error: if_nametoindex error\n");
        return NULL;
    }
    
    if (sysctl(mib, 6, NULL, &len, NULL, 0) < 0) {
        printf("Error: sysctl, take 1\n");
        return NULL;
    }
    
    if ((buf = malloc(len)) == NULL) {
        printf("Could not allocate memory. error!\n");
        return NULL;
    }
    
    if (sysctl(mib, 6, buf, &len, NULL, 0) < 0) {
        printf("Error: sysctl, take 2");
        free(buf);
        return NULL;
    }
    
    ifm = (struct if_msghdr *)buf;
    sdl = (struct sockaddr_dl *)(ifm + 1);
    ptr = (unsigned char *)LLADDR(sdl);
    NSString *outstring = [NSString stringWithFormat:@"%02X:%02X:%02X:%02X:%02X:%02X", 
                           *ptr, *(ptr+1), *(ptr+2), *(ptr+3), *(ptr+4), *(ptr+5)];
    free(buf);
    
    return outstring;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Public Methods

- (NSString *) uniqueDeviceIdentifier{
    NSString *macaddress = [self macaddress];
    NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    
    NSString *stringToHash = [NSString stringWithFormat:@"%@%@",macaddress,bundleIdentifier];
    NSString *uniqueIdentifier = [self stringFromMD5:stringToHash];
    
    return uniqueIdentifier;
}

- (NSString *) uniqueGlobalDeviceIdentifier{
    NSString *macaddress = [self macaddress];
    NSString *uniqueIdentifier = [self stringFromMD5:macaddress];
    
    return uniqueIdentifier;
}

- (id) initWithApplicationCode:(NSString *)_appCode appName:(NSString *)_appName{
	if(self = [super init]) {
		self.supportedOrientations = PWOrientationPortrait | PWOrientationPortraitUpsideDown | PWOrientationLandscapeLeft | PWOrientationLandscapeRight;
		self.appCode = _appCode;
		self.appName = _appName;
		self.navController = [UIApplication sharedApplication].keyWindow.rootViewController;
		internalIndex = 0;
		pushNotifications = [[NSMutableDictionary alloc] init];
	}
	
	return self;
}

- (id) initWithApplicationCode:(NSString *)_appCode navController:(UIViewController *) _navController appName:(NSString *)_appName{
	if (self = [super init]) {
		self.supportedOrientations = PWOrientationPortrait | PWOrientationPortraitUpsideDown | PWOrientationLandscapeLeft | PWOrientationLandscapeRight;
		self.appCode = _appCode;
		self.navController = _navController;
		self.appName = _appName;
		internalIndex = 0;
		pushNotifications = [[NSMutableDictionary alloc] init];
	}
	
	return self;
}

- (void) closeAction {
	[navController dismissModalViewControllerAnimated:YES];
}

- (void) showPushPage:(NSString *)pageId {
	NSString *url = [NSString stringWithFormat:kServiceHtmlContentFormatUrl, pageId];
	HtmlWebViewController *vc = [[HtmlWebViewController alloc] initWithURLString:url];
	vc.supportedOrientations = supportedOrientations;
	
	// Create the navigation controller and present it modally.
	UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:vc];
	vc.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:@"Back" style:UIBarButtonItemStyleDone target:self action:@selector(closeAction)] autorelease];
    
	[navController presentModalViewController:navigationController animated:YES];
	
	[navigationController release];
	[vc release];
}

- (void) sendDevTokenToServer:(NSString *)deviceID {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
	NSString * appLocale = @"en";
	NSLocale * locale = (NSLocale *)CFLocaleCopyCurrent();
	NSString * localeId = [locale localeIdentifier];
	
	if([localeId length] > 2)
		localeId = [localeId stringByReplacingCharactersInRange:NSMakeRange(2, [localeId length]-2) withString:@""];
	
	[locale release]; locale = nil;
	
	appLocale = localeId;
	
	NSArray * languagesArr = (NSArray *) CFLocaleCopyPreferredLanguages();	
	if([languagesArr count] > 0)
	{
		NSString * value = [languagesArr objectAtIndex:0];
		
		if([value length] > 2)
			value = [value stringByReplacingCharactersInRange:NSMakeRange(2, [value length]-2) withString:@""];
		
		appLocale = [[value copy] autorelease];
	}
	
	[languagesArr release]; languagesArr = nil;
    
    NSString *udid = [self uniqueGlobalDeviceIdentifier];
	
	//create JSON data 
	NSError *error = nil;
	NSString *jsonRequestData = [NSString stringWithFormat:@"{\"request\":{\"language\":\"%@\",\"application\":\"%@\",\"device_id\":\"%@\", \"hw_id\":\"%@\", \"timezone\":%d, \"device_type\":1}}",
                                 appLocale, appCode, deviceID, udid, [[NSTimeZone localTimeZone] secondsFromGMT]];
	
	if (error) {
		NSLog(@"Send Data Error: %@", error);
		return;
	}
	
	NSLog(@"Sending request: %@", jsonRequestData);
	NSLog(@"Opening url: %@", kServicePushNotificationUrl);
	
	NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:kServicePushNotificationUrl]];
	[urlRequest setHTTPMethod:@"POST"];
	[urlRequest addValue:@"application/json; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
	[urlRequest setHTTPBody:[jsonRequestData dataUsingEncoding:NSUTF8StringEncoding]];
	
	//Send data to server
	NSURLResponse *response = nil;
	NSData * responseData = [NSURLConnection sendSynchronousRequest:urlRequest returningResponse:&response error:&error];
	[urlRequest release]; urlRequest = nil;
	
	NSString *responseString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
	NSLog(@"Response string: %@", responseString);
	[responseString release]; responseString = nil;
	
	NSLog(@"Error: %@", error);
	NSLog(@"Registered for push notifications: %@", deviceID);
	
	[pool release]; pool = nil;
}

- (void) handlePushRegistration:(NSData *)devToken {
	NSMutableString *deviceID = [NSMutableString stringWithString:[devToken description]];
	
	//Remove <, >, and spaces
	[deviceID replaceOccurrencesOfString:@"<" withString:@"" options:1 range:NSMakeRange(0, [deviceID length])];
	[deviceID replaceOccurrencesOfString:@">" withString:@"" options:1 range:NSMakeRange(0, [deviceID length])];
	[deviceID replaceOccurrencesOfString:@" " withString:@"" options:1 range:NSMakeRange(0, [deviceID length])];
	
	[[NSUserDefaults standardUserDefaults] setObject:deviceID forKey:@"PWPushUserId"];
	
	[self performSelectorInBackground:@selector(sendDevTokenToServer:) withObject:deviceID];
}

- (NSString *) getPushToken {
	return [[NSUserDefaults standardUserDefaults] objectForKey:@"PWPushUserId"];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	if(buttonIndex != 1) {
		if(!alertView.tag)
			return;
		
		[pushNotifications removeObjectForKey:[NSNumber numberWithInt:alertView.tag]];
		return;
	}
	
	NSDictionary *lastPushDict = [pushNotifications objectForKey:[NSNumber numberWithInt:alertView.tag]];
	NSString *htmlPageId = [lastPushDict objectForKey:@"h"];
	if(htmlPageId) {
		[self showPushPage:htmlPageId];
	}
    
	NSString *linkUrl = [lastPushDict objectForKey:@"l"];	
	if(linkUrl) {
		[[UIApplication sharedApplication] openURL:[NSURL URLWithString:linkUrl]];
	}
	
	[delegate onPushAccepted:self withNotification:lastPushDict];
	[pushNotifications removeObjectForKey:[NSNumber numberWithInt:alertView.tag]];
}

- (BOOL) handlePushReceived:(NSDictionary *)userInfo {
	//set the application badges icon to 0
	[[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
	
	BOOL isPushOnStart = NO;
	NSDictionary *pushDict = [userInfo objectForKey:@"aps"];
	if(!pushDict) {
		//try as launchOptions dictionary
		userInfo = [userInfo objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
		pushDict = [userInfo objectForKey:@"aps"];
		isPushOnStart = YES;
	}
	
	if (!pushDict)
		return NO;
	
	//check if the app is really running
	if([[UIApplication sharedApplication] respondsToSelector:@selector(applicationState)] && [[UIApplication sharedApplication] applicationState] != UIApplicationStateActive) {
		isPushOnStart = YES;
	}
	
	if([delegate respondsToSelector:@selector(onPushReceived: onStart:)] ) {
		[delegate onPushReceived:self onStart:isPushOnStart];
		return YES;
	}
	
	//NSString *alertMsg = [pushDict objectForKey:@"alert"];
	//	NSString *badge = [pushDict objectForKey:@"badge"];
	//	NSString *sound = [pushDict objectForKey:@"sound"];
	NSString *htmlPageId = [userInfo objectForKey:@"h"];
	//	NSString *customData = [userInfo objectForKey:@"u"];
	NSString *linkUrl = [userInfo objectForKey:@"l"];
	
	//Do not display alert for PhoneGap plugin, just pass the push to the javascript
	//the app is running, display alert only
/*	if(!isPushOnStart) {
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:self.appName message:alertMsg delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
		alert.tag = ++internalIndex;
		[pushNotifications setObject:userInfo forKey:[NSNumber numberWithInt:internalIndex]];
		[alert show];
		[alert release];
		return YES;
	}
*/	
	if(htmlPageId) {
		[self showPushPage:htmlPageId];
	}
    
	if(linkUrl) {
		[[UIApplication sharedApplication] openURL:[NSURL URLWithString:linkUrl]];
	}
	
	[delegate onPushAccepted:self withNotification:userInfo];
	return YES;
}

- (NSDictionary *) getApnPayload:(NSDictionary *)pushNotification {
	return [pushNotification objectForKey:@"aps"];
}

- (NSString *) getCustomPushData:(NSDictionary *)pushNotification {
	return [pushNotification objectForKey:@"u"];
}

- (void) dealloc {
	self.delegate = nil;
	self.appCode = nil;
	self.navController = nil;
	self.pushNotifications = nil;
	
	[super dealloc];
}

@end

@implementation HtmlWebViewController

@synthesize webview, activityIndicator;
@synthesize supportedOrientations;

- (id)initWithURLString:(NSString *)url {
	if(self = [super init]) {
		urlToLoad = [url retain];
	}
	
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	
	self.title = @"";
	
	webview = [[UIWebView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height)];
	webview.delegate = self;
	webview.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self.view addSubview:webview];
	
	activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
	[activityIndicator startAnimating];
	activityIndicator.frame = CGRectMake(self.view.frame.size.width / 2.0 - activityIndicator.frame.size.width / 2.0, self.view.frame.size.height / 2.0 - activityIndicator.frame.size.height / 2.0, activityIndicator.frame.size.width, activityIndicator.frame.size.height);
	[self.view addSubview:activityIndicator];
	
//	[webview setBackgroundColor:[UIColor clearColor]];
	webview.opaque = YES;
	webview.scalesPageToFit = NO;
	
	[webview loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:urlToLoad]]];
}

- (void)dealloc {
	webview.delegate = nil;
	[webview release];
	[urlToLoad release];
	
    [super dealloc];
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
	if ((toInterfaceOrientation == UIInterfaceOrientationPortrait && (supportedOrientations & PWOrientationPortrait)) ||
		(toInterfaceOrientation == UIInterfaceOrientationPortrait && (supportedOrientations & PWOrientationPortraitUpsideDown)) ||
		(toInterfaceOrientation == UIInterfaceOrientationLandscapeLeft && (supportedOrientations & PWOrientationLandscapeLeft)) || 
		(toInterfaceOrientation == UIInterfaceOrientationLandscapeRight && (supportedOrientations & PWOrientationLandscapeRight))) {
		return YES;
	}
	return NO;
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
	activityIndicator.hidden = NO;
	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
	activityIndicator.hidden = YES;
	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
	if ([error code] != -999) {
		activityIndicator.hidden = YES;
		[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
	}
}

- (BOOL) webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
	if (navigationType == UIWebViewNavigationTypeLinkClicked) {
		[[UIApplication sharedApplication] openURL:[request URL]];
		return NO;
	}
	
	return YES;
}

@end


