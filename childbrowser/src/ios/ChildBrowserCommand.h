//
//  PhoneGap ! ChildBrowserCommand
//
//
//  Created by Jesse MacFadyen on 10-05-29.
//  Copyright 2010 Nitobi. All rights reserved.
//

#import <Foundation/Foundation.h>
#ifdef CORDOVA_FRAMEWORK
	#import <Cordova/CDVPlugin.h>
#else
	#import "CDVPlugin.h"
#endif
#import "ChildBrowserViewController.h"

@interface ChildBrowserCommand : CDVPlugin <ChildBrowserDelegate>  {
    NSString* callbackId;
    ChildBrowserViewController* childBrowser;

    NSNumber* CLOSE_EVENT;
    NSNumber* LOCATION_CHANGE_EVENT;
    NSNumber* OPEN_EXTERNAL_EVENT;
}

@property (nonatomic, retain) ChildBrowserViewController *childBrowser;
@property (nonatomic, retain) NSString *callbackId;
@property (nonatomic, retain) NSNumber *CLOSE_EVENT;
@property (nonatomic, retain) NSNumber *LOCATION_CHANGE_EVENT;
@property (nonatomic, retain) NSNumber *OPEN_EXTERNAL_EVENT;

-(void) showWebPage:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
-(void) onChildLocationChange:(NSString*)newLoc;

-(NSDictionary*) dictionaryForEvent:(NSNumber*)event;

@end
