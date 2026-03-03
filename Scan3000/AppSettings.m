//
//  AppSettings.m
//  Scan3000
//
//  Created by Pius Ott on 14/1/2026.
//

#import <Foundation/Foundation.h>
#import "AppSettings.h"
#import "Utilities.h"

#define APP_SETTINGS_FILE @"settings.json"

@implementation AppSettings

// -------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        // initialise settings with default values. If we're loading a config file and that has settings defined,
        // these will then overwritte the ones we initialise here.
        _lastError = @"";
        _cellsToRead = 10;
        _usbPortName = @"/dev/cu.usbserial-0001";   // default port on my desktop PC
        _logFileName = @"ScanBrain.log";
        _imagePath = @"~/ScanBrain/Images";
        _capturePause = 2;
        _cameraResolution.width = 1920;
        _cameraResolution.height = 1080;
        _useOlympusCam = true;                      // default to the better camera
        [self readSettingsFromFile];
    }
    return self;
}

// -------------------------------------------------------------------------------------------


/// Load the configuration settings. If no file is defined, we just use default values and create the file.
- (void)readSettingsFromFile
{
    _configFile = [[self applicationSupportDirectory] URLByAppendingPathComponent:APP_SETTINGS_FILE];
    [self ensureConfigExists];  // create a default configuration file if none exists yet
    NSMutableDictionary *config = [self loadConfig];
    
    _cellsToRead = [config[@"CELLS_TO_READ"] integerValue];
    _capturePause = [config[@"CAPTURE_PAUSE"] integerValue];
    _usbPortName = config[@"USB_PORT"];
    _logFileName = config[@"LOGFILE_NAME"];
    _imagePath = config[@"IMAGE_LOCATION"];
    _useOlympusCam = [config[@"USE_OLYMPUS_CAM"] boolValue];
    
    // parse the resolution height and width
    NSDictionary *resolution = config[@"WEBCAM_RESOLUTION"];
    _cameraResolution.width = [resolution[@"width"] integerValue];
    _cameraResolution.height = [resolution[@"height"] integerValue];
}

// -------------------------------------------------------------------------------------------

/// Find the Application Support directory for our application. If none exists, create it.
/// This will be something like "~/Library/Application Support/<bundle identifier>/" e.g. "~/Library/Application Support/WorldDom.Scan3000/".
- (NSURL *)applicationSupportDirectory
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *baseURL = [[fm URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask] firstObject];
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    NSURL *appFolder = [baseURL URLByAppendingPathComponent:bundleID isDirectory:YES];

    // create the directory if it doesn't exist yet
    if (![fm fileExistsAtPath:appFolder.path])
    {
        [fm createDirectoryAtURL:appFolder
     withIntermediateDirectories:YES
                      attributes:nil
                           error:nil];
    }
    
    return appFolder;
}

// -------------------------------------------------------------------------------------------

- (void)ensureConfigExists
{
    NSFileManager *fm = [NSFileManager defaultManager];

    if (![fm fileExistsAtPath:_configFile.path])
    {
        NSDictionary *defaultConfig = @{
            @"CELLS_TO_READ": @4,
            @"USB_PORT": @"/dev/cu.usbserial-0001",
            @"LOGFILE_NAME": @"~/dev/XCode/ModemCommTest/ScanBrain.log",
            @"IMAGE_LOCATION": @"~/Pictures/Scan3000",
            @"CAPTURE_PAUSE": @3,
            @"WEBCAM_RESOLUTION": @{
                    @"width": @1920,
                    @"height": @1080
            },
            @"USE_OLYMPUS_CAM": @YES
        };

        NSData *jsonData =
            [NSJSONSerialization dataWithJSONObject:defaultConfig
                                            options:NSJSONWritingPrettyPrinted
                                              error:nil];

        [jsonData writeToURL:_configFile atomically:YES];
    }
}

// -------------------------------------------------------------------------------------------

- (NSMutableDictionary *)loadConfig
{
    NSURL *configURL = [self configFile];
    NSData *data = [NSData dataWithContentsOfURL:configURL];
    if (!data)
        return nil;

    NSDictionary *json =
        [NSJSONSerialization JSONObjectWithData:data
                                        options:0
                                          error:nil];

    return [json mutableCopy];
}

// -------------------------------------------------------------------------------------------

- (void)saveConfig:(NSDictionary *)config
{

    NSURL *configURL = [self configFile];

    NSData *jsonData =
        [NSJSONSerialization dataWithJSONObject:config
                                        options:NSJSONWritingPrettyPrinted
                                          error:nil];

    [jsonData writeToURL:configURL atomically:YES];
}

// -------------------------------------------------------------------------------------------

@end
