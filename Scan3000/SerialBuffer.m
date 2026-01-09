//
//  SerialBuffer.m
//  FIFO buffer that holds data read via the USB serial port until it can be processed
//
//  Created by Pius Ott on 3/12/2024.
//  Copyright © 2024 Worlddom. All rights reserved.
//

#import "SerialBuffer.h"
#import "ArduinoResponse.h"

@implementation SerialBuffer

// -------------------------------------------------------------------------------------------

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _buffer = [NSMutableArray array];
    }
    return self;
}

// -------------------------------------------------------------------------------------------

- (void)enqueue:(NSString *)str
{
    /*
    NSComparisonResult result = [str compare:@CMD_OK];
    if (result == NSOrderedSame)
        [self.buffer addObject:@CMD_OK];
    
    if (strncmp(string, CMD_OK, strlen(CMD_OK)) == 0)
        [self.buffer addObject:CMD_OK];
    else if (strncmp(str, RSP_ERR, strlen(RSP_ERR)) == 0)
        response = Error;
    else if (strncmp(str, CMD_READY, strlen(CMD_READY)) == 0)
        response = Ready;
    else if (strncmp(str, CMD_ATCELL, strlen(CMD_ATCELL)) == 0)
        response = AtCell;
*/
    
    
    [self.buffer addObject:str];
}

// -------------------------------------------------------------------------------------------

- (NSString *)dequeue
{
    if ([self isEmpty])
    {
        return nil; // Return nil if the buffer is empty
    }
    
    NSString *firstString = self.buffer[0];
    [self.buffer removeObjectAtIndex:0];
    return firstString;
}

// -------------------------------------------------------------------------------------------

- (NSUInteger)size
{
    return self.buffer.count;
}

// -------------------------------------------------------------------------------------------

- (BOOL)isEmpty
{
    return self.buffer.count == 0;
}

// -------------------------------------------------------------------------------------------

@end



