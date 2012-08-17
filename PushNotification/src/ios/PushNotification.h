//
// PushNotification.h
//
// Based on the Push Notifications Cordova Plugin by Olivier Louvignes on 06/05/12.
// Modified by Max Konev on 18/05/12.
//
// Pushwoosh Push Notifications Plugin for Cordova iOS
// www.pushwoosh.com
//
// MIT Licensed

#import <Foundation/Foundation.h>
#import <Cordova/CDVPlugin.h>

//Pushwoosh SDK START
@class PushNotificationManager;

@protocol PushNotificationDelegate

@optional
//handle push notification, display alert, if this method is implemented onPushAccepted will not be called, internal message boxes will not be displayed
- (void) onPushReceived:(PushNotificationManager *)pushManager onStart:(BOOL)onStart;

//user pressed OK on the push notification
- (void) onPushAccepted:(PushNotificationManager *)pushManager withNotification:(NSDictionary *)pushNotification;
@end

typedef enum enumHtmlPageSupportedOrientations {
	PWOrientationPortrait = 1 << 0,
	PWOrientationPortraitUpsideDown = 1 << 1,
	PWOrientationLandscapeLeft = 1 << 2,
	PWOrientationLandscapeRight = 1 << 3,
} PWSupportedOrientations;

@interface PushNotificationManager : NSObject {
	NSString *appCode;
	NSString *appName;
	UIViewController *navController;

	NSInteger internalIndex;
	NSMutableDictionary *pushNotifications;
	NSObject<PushNotificationDelegate> *delegate;
}

@property (nonatomic, copy) NSString *appCode;
@property (nonatomic, copy) NSString *appName;
@property (nonatomic, assign) UIViewController *navController;
@property (nonatomic, retain) NSDictionary *pushNotifications;
@property (nonatomic, assign) NSObject<PushNotificationDelegate> *delegate;
@property (nonatomic, assign) PWSupportedOrientations supportedOrientations;

- (id) initWithApplicationCode:(NSString *)appCode appName:(NSString *)appName;
- (id) initWithApplicationCode:(NSString *)appCode navController:(UIViewController *) navController appName:(NSString *)appName;

//sends the token to server
- (void) handlePushRegistration:(NSData *)devToken;
- (NSString *) getPushToken;

//if the push is received when the app is running
- (BOOL) handlePushReceived:(NSDictionary *) userInfo;

//gets apn payload
- (NSDictionary *) getApnPayload:(NSDictionary *)pushNotification;

//get custom data from the push payload
- (NSString *) getCustomPushData:(NSDictionary *)pushNotification;

@end
//Pushwoosh SDK END

@interface PushNotification : CDVPlugin <PushNotificationDelegate> {

	NSMutableDictionary* callbackIds;
	PushNotificationManager *pushManager;
	NSString *startPushData;
}

@property (nonatomic, retain) NSMutableDictionary* callbackIds;
@property (nonatomic, retain) PushNotificationManager *pushManager;
@property (nonatomic, copy) NSString *startPushData;

- (void)registerDevice:(NSMutableArray *)arguments withDict:(NSMutableDictionary*)options;
- (void)onDeviceReady:(NSMutableArray *)arguments withDict:(NSMutableDictionary*)options;
- (void)didRegisterForRemoteNotificationsWithDeviceToken:(NSString*)deviceToken;
- (void)didFailToRegisterForRemoteNotificationsWithError:(NSError*)error;
+ (NSMutableDictionary*)getRemoteNotificationStatus;
- (void)getRemoteNotificationStatus:(NSMutableArray *)arguments withDict:(NSMutableDictionary*)options;
- (void)setApplicationIconBadgeNumber:(NSMutableArray *)arguments withDict:(NSMutableDictionary*)options;
- (void)cancelAllLocalNotifications:(NSMutableArray *)arguments withDict:(NSMutableDictionary*)options;

@end

//Pushwoosh SDK START
@interface HtmlWebViewController : UIViewController<UIWebViewDelegate> {
	UIWebView *webview;
	UIActivityIndicatorView *activityIndicator;
	
	NSString *urlToLoad;
}

- (id)initWithURLString:(NSString *)url;	//this method is to use it as a standalone webview

@property (nonatomic, retain) IBOutlet UIWebView *webview;
@property (nonatomic, retain) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (nonatomic, assign) PWSupportedOrientations supportedOrientations;

@end
//Pushwoosh SDK END

#ifdef DEBUG
#   define DLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#else
#   define DLog(...)
#endif
#define ALog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
