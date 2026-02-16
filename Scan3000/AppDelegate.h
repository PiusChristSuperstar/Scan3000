//
//  AppDelegate.h
//  Scan3000
//
//  Created by Pius Ott on 9/1/2026.
//

#import <Cocoa/Cocoa.h>
#import "AppSettings.h"
/*
#import <OLYCameraKit/OLYCamera.h>
#import <OLYCameraKit/OLYCameraError.h>
*/
@class SerialManager;

/*
// ------------ Olympus Camera values -----------------
extern NSString *const kAppDelegateCameraDidChangeConnectionStateNotification;
extern NSString *const kConnectionStateKey;
extern NSString *const kConnectionStateConnected;
extern NSString *const kConnectionStateDisconnected;

extern NSString *ICSCameraPropertyTakemode;
extern NSString *ICSCameraPropertyDrivemode;
extern NSString *ICSCameraPropertyApertureValue;
extern NSString *ICSCameraPropertyShutterSpeed;
extern NSString *ICSCameraPropertyExposureCompensation;
extern NSString *ICSCameraPropertyWhiteBalance;
extern NSString *ICSCameraPropertyIsoSensitivity;
extern NSString *ICSCameraPropertyBatteryLevel;
extern NSString *ICSCameraPropertyRecview;
// ------------ Olympus Camera values -----------------
*/
@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (strong, nonatomic) SerialManager *serialManager;
@property (strong, nonatomic) AppSettings *appSettings;

@end
/*
extern OLYCamera *AppDelegateCamera();
extern void AppDelegateCameraDisconnectWithPowerOff(BOOL powerOff);
*/
