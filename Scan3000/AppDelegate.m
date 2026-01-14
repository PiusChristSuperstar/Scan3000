//
//  AppDelegate.m
//  Scan3000
//
//  Created by Pius Ott on 9/1/2026.
//

#import "AppDelegate.h"
#import "SerialManager.h"


@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    
}

- (AppSettings *)appSettings
{
    // if we haven't loaded the settings yet, do so now on first use.
    if (!_appSettings)
    {
        // load the application settings, either from an xconfig file or if not found, use default values
        self.appSettings = [[AppSettings alloc] init];
    }
    return _appSettings;
}

- (SerialManager *)serialManager
{
    // create the SerialManager instance on first use
    if (!_serialManager)
    {
        _serialManager = [[SerialManager alloc] init];
        _serialManager.appSettings = self.appSettings;
        [_serialManager start];
    }
    return _serialManager;
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    [self.serialManager stop];
    /*
    // Insert code here to tear down your application
    [self stopResponseReaderThread];
    [self stopUSBReaderThread];
     */
}


- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}


@end
