//
//  AppDelegate.h
//  Scan3000
//
//  Created by Pius Ott on 9/1/2026.
//

#import <Cocoa/Cocoa.h>
#import "AppSettings.h"

@class SerialManager;

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (strong, nonatomic) SerialManager *serialManager;
@property (strong, nonatomic) AppSettings *appSettings;

@end

