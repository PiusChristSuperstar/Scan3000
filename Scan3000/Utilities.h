//
//  Utilities.h
//  Various utility functions, mostly around string manipulation
//
//  Created by Pius Ott on 17/12/2024.
//  Copyright © 2024 WorldDom. All rights reserved.
//

#ifndef Utilities_h
#define Utilities_h

#import "ArduinoResponse.h"

@interface Utilities : NSObject

// ------------------------------------------------------------------------------------------------

+(NSString *) convertCFTypeRefToNSString:(CFTypeRef)cfType;

+(BOOL)createPathIfNotExist:(NSString *)fullPath;

+(NSInteger) getNumberFromString:(NSString *)input;

+(BOOL) getBoolFromString:(NSString *)input;

+(char *) logString:(char *)str;

+ (ArduinoResponse) translateResponse:(char *)str;

@end

#endif /* Utilities_h */
