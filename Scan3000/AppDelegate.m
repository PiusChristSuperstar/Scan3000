//
//  AppDelegate.m
//  Scan3000
//
//  Created by Pius Ott on 9/1/2026.
//

#import "AppDelegate.h"
#import "SerialManager.h"

#import "OlympusCamera/Reachability.h"

#import <Foundation/Foundation.h>

/*
NSString *const kAppDelegateCameraDidChangeConnectionStateNotification = @"kAppDelegateCameraDidChangeConnectionStateNotification";
NSString *const kConnectionStateKey = @"state";
NSString *const kConnectionStateConnected = @"connected";
NSString *const kConnectionStateDisconnected = @"disconnected";

NSString *ICSCameraPropertyTakemode = @"TAKEMODE";
NSString *ICSCameraPropertyDrivemode = @"TAKE_DRIVE";
NSString *ICSCameraPropertyApertureValue = @"APERTURE";
NSString *ICSCameraPropertyShutterSpeed = @"SHUTTER";
NSString *ICSCameraPropertyExposureCompensation = @"EXPREV";
NSString *ICSCameraPropertyWhiteBalance = @"WB";
NSString *ICSCameraPropertyIsoSensitivity = @"ISO";
NSString *ICSCameraPropertyBatteryLevel = @"BATTERY_LEVEL";
NSString *ICSCameraPropertyRecview = @"RECVIEW";


@interface AppDelegate () <OLYCameraConnectionDelegate>

@property (strong, nonatomic) dispatch_queue_t connectionQueue;
@property (strong, nonatomic) OLYCamera *camera;
@property (strong, nonatomic) Reachability *reachabilityForCamera;
@property (assign, nonatomic) BOOL connecting;

@end
*/

@implementation AppDelegate

// -------------------------------------------------------------------------------------------

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    
}
/*
+ (void)initialize
{
    if ([self class] != [AppDelegate class])
    {
        return;
    }
    
    NSDictionary *userDefaults = @{@"live_preview_quality": NSStringFromSize(OLYCameraLiveViewSizeQVGA),
                                   ICSCameraPropertyTakemode: @"<TAKEMODE/iAuto>",
                                   ICSCameraPropertyDrivemode: @"<TAKE_DRIVE/DRIVE_NORMAL>",
                                   ICSCameraPropertyRecview: @"<RECVIEW/ON>"};
    [[NSUserDefaults standardUserDefaults] registerDefaults:userDefaults];
}

- (BOOL)application:(NSApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    _camera = [[OLYCamera alloc] init];
    [_camera setConnectionDelegate:self];
    
    _connectionQueue = dispatch_queue_create([NSString stringWithFormat:@"%@.queue", [NSBundle mainBundle].bundleIdentifier].UTF8String, DISPATCH_QUEUE_SERIAL);
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didChangeNetworkReachability:) name:kReachabilityChangedNotification object:nil];
    _reachabilityForCamera = [Reachability reachabilityWithHostName:_camera.host];
    
    return YES;
}

- (void)applicationDidBecomeActive:(NSApplication *)application
{
    [self startScanningCamera];
}

- (void)applicationWillResignActive:(NSApplication *)application
{
    [self.reachabilityForCamera stopNotifier];
    [self disconnectWithPowerOff:NO];
}
*/
// -------------------------------------------------------------------------------------------

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

// -------------------------------------------------------------------------------------------

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

// -------------------------------------------------------------------------------------------

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    [self.serialManager stop];
}

// -------------------------------------------------------------------------------------------


- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app
{
    return YES;
}

// -------------------------------------------------------------------------------------------
// -------------------------------------------------------------------------------------------
@end

/*
 

#pragma mark -

- (void)startScanningCamera
{
    [self.reachabilityForCamera startNotifier];
    [self startConnectingToCamera];
}

- (void)startConnectingToCamera
{
    if (self.reachabilityForCamera.currentReachabilityStatus != ReachableViaWiFi)
    {
        return;
    }
    
    if (self.connecting)
    {
        return;
    }
    
    self.connecting = YES;
    
    dispatch_async(self.connectionQueue, ^{
        NSError *error = nil;
        if (![self->_camera connect:OLYCameraConnectionTypeWiFi error:&error])
        {
            [self alertConnectingFailed:error];
            return;
        }
        
        NSString *userLivePreviewQuality = [[NSUserDefaults standardUserDefaults] stringForKey:@"live_preview_quality"];
        if (userLivePreviewQuality)
        {
            if (![self->_camera changeLiveViewSize:NSSizeFromString(userLivePreviewQuality) error:&error])
            {
                NSLog(@"You had better uninstall this application and install it again.");
                [self alertConnectingFailed:error];
                return;
            }
        }
        
        if (![self->_camera changeRunMode:OLYCameraRunModeRecording error:&error])
        {
            [self alertConnectingFailed:error];
            return;
        }
        
        // Restores my settings.
        if (self->_camera.connected)
        {
            NSArray *names = @[ICSCameraPropertyTakemode,
                               ICSCameraPropertyDrivemode,
                               ICSCameraPropertyApertureValue,
                               ICSCameraPropertyShutterSpeed,
                               ICSCameraPropertyExposureCompensation,
                               ICSCameraPropertyWhiteBalance,
                               ICSCameraPropertyIsoSensitivity,
                               ICSCameraPropertyRecview];
            NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
            NSMutableDictionary *values = [[NSMutableDictionary alloc] initWithCapacity:names.count];
            [names enumerateObjectsUsingBlock:^(id name, NSUInteger idx, BOOL *stop)
             {
                id value = [userDefaults valueForKey:name];
                if (value)
                {
                    [values setObject:value forKey:name];
                }
            }];
            
            if (values.count > 0)
            {
                if (![self->_camera setCameraPropertyValues:values error:&error])
                {
                    NSLog(@"To change the camera properties is failed: %@", error ? error : @"Unknown error");
                }
            }
        }
        
        if (!self->_camera.liveViewEnabled)
        { // Please refer a document about OLYCamera.autoStartLiveView.
            // Start the live-view.
            // If you forget calling this method, live view will not be displayed on the screen.
            if (![self->_camera startLiveView:&error])
            {
                NSLog(@"To start the live-view is failed: %@", error ? error : @"Unknown error");
                self.connecting = NO;
                return;
            }
        }
        
        self.connecting = NO;
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kAppDelegateCameraDidChangeConnectionStateNotification object:self userInfo:@{kConnectionStateKey: kConnectionStateConnected}];
    });
}

- (void)alertConnectingFailed:(NSError *)error
{
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:@"Connect failed"];
    [alert setInformativeText:error.localizedDescription];
    [alert addButtonWithTitle:@"Retry"];
    [alert addButtonWithTitle:@"Cancel"];
    NSInteger response = [alert runModal]; // Runs the alert as an app-modal dialog
    
    if (response == NSAlertFirstButtonReturn)
    {
        // retry
        self.connecting = NO;
        [self performSelector:@selector(startScanningCamera) withObject:nil afterDelay:0.5];
    }
    else if (response == NSAlertSecondButtonReturn)
    {
        // cancel - nothing to do
    }
}


- (void)disconnectWithPowerOff:(BOOL)powerOff
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kAppDelegateCameraDidChangeConnectionStateNotification object:self userInfo:@{kConnectionStateKey: kConnectionStateDisconnected}];
    
    dispatch_sync(self.connectionQueue, ^{
        NSError *error = nil;
        
        // Stop the live-view.
        if (![_camera stopLiveView:&error]) {
            NSLog(@"To stop the live-view is failed: %@", error ? error : @"Unknown error");
        }
        
        // Stores current settings.
        if (_camera.connected)
        {
            NSArray *names = @[ICSCameraPropertyTakemode,
                               ICSCameraPropertyDrivemode,
                               ICSCameraPropertyApertureValue,
                               ICSCameraPropertyShutterSpeed,
                               ICSCameraPropertyExposureCompensation,
                               ICSCameraPropertyWhiteBalance,
                               ICSCameraPropertyIsoSensitivity,
                               ICSCameraPropertyRecview];
            NSDictionary *values = [_camera cameraPropertyValues:[NSSet setWithArray:names] error:&error];
            if (values) {
                NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
                [values enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                    [userDefaults setObject:obj forKey:key];
                }];
            } else {
                NSLog(@"To get the camera properties is failed: %@", error ? error : @"Unknown error");
            }
        }
        
        if (![_camera disconnectWithPowerOff:powerOff error:&error])
        {
            NSLog(@"To disconnect from the camera is failed: %@", error ? error : @"Unknown error");
        }
    });
}

#pragma mark - Reachabiliry

- (void)didChangeNetworkReachability:(Reachability *)noteObject
{
    [self startConnectingToCamera];
}

#pragma mark - OLYCameraConnectionDelegate

- (void)camera:(OLYCamera *)camera disconnectedByError:(NSError *)error
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kAppDelegateCameraDidChangeConnectionStateNotification object:self userInfo:@{kConnectionStateKey: kConnectionStateDisconnected}];
}

@end

OLYCamera *AppDelegateCamera()
{
    AppDelegate *delegate = (AppDelegate *)[[NSApplication sharedApplication] delegate];
    if (!delegate)
    {
        return nil;
    }
    return delegate.camera;
}

void AppDelegateCameraDisconnectWithPowerOff(BOOL powerOff)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        AppDelegate *delegate = (AppDelegate *)[[NSApplication sharedApplication] delegate];
        [delegate disconnectWithPowerOff:powerOff];
    });
}
*/
