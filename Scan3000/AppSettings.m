//
//  AppSettings.m
//  Scan3000
//
//  Created by Pius Ott on 14/1/2026.
//

#import <Foundation/Foundation.h>
#import "AppSettings.h"
#import "Utilities.h"

#define APP_SETTINGS_FILE @"settings.xcconfig"

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
        
        [self readSettingsFromFile];
    }
    return self;
}

// -------------------------------------------------------------------------------------------


/// Load the configuration settings. If no file is defined, or the file could not be opened, we just use default values.
- (void)readSettingsFromFile
{

    NSError *error = nil;
    _configFile = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                             NSUserDomainMask,
                                             YES).firstObject stringByAppendingPathComponent:APP_SETTINGS_FILE];
    
    NSString *fileContents = [NSString stringWithContentsOfFile:_configFile encoding:NSUTF8StringEncoding error:&error];
    
    if (error)
    {
        _lastError = [NSString stringWithFormat:
                      @"Error reading config file: [%@] - using default configurations instead\n", error.localizedDescription];
        return;
    }

    // split all lines into an array
    NSArray *configLines = [fileContents componentsSeparatedByString:@"\n"];
    
    for (int i = 0; i < configLines.count; i++)
    {
        if ([configLines[i] hasPrefix:@"//"])
        {
            // Comment line, ignore it
        }
        else
        {
            NSArray *components = [configLines[i] componentsSeparatedByString:@"="];
            
            // Ensure there are exactly two components
            if (components.count == 2)
            {
                NSString *settingName = [components[0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                NSString *valueWithQuotes = components[1];
                
                // Strip the single quotes and line end from the value
                NSString *settingValue = [valueWithQuotes stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"'\n"]];
                
                NSLog(@"Setting: %@, Value: %@\n", settingName, settingValue);
                if ([settingName isEqualToString:@"CELLS_TO_READ"])
                {
                    _cellsToRead = [Utilities getNumberFromString:settingValue];
                }
                else if ([settingName isEqualToString:@"CAPTURE_PAUSE"])
                {
                    _capturePause = [Utilities getNumberFromString:settingValue];
                }
                else if ([settingName isEqualToString:@"USB_PORT"])
                {
                    _usbPortName = settingValue;
                }
                else if ([settingName isEqualToString:@"LOGFILE_NAME"])
                {
                    _logFileName = settingValue;
                }
                else if ([settingName isEqualToString:@"IMAGE_LOCATION"])
                {
                    _imagePath = settingValue;
                }
            }
            else
            {
                //NSLog(@"The input string [%@] is invalid", configLine);
            }
        }
    }
}

// -------------------------------------------------------------------------------------------

@end
