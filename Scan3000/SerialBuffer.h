//
//  SerialBuffer.h
//  FIFO buffer that holds data read via the USB serial port until it can be processed
//
//  Created by Pius Ott on 3/12/2024.
//  Copyright © 2024 Worlddom. All rights reserved.
//
#import <Foundation/Foundation.h>

@interface SerialBuffer : NSObject
@property (nonatomic, strong) NSMutableArray<NSString *> *buffer;

- (void)enqueue:(NSString *)string;  // Decipher if the data is a valid projector instruction and if so, add to the end of the buffer
- (NSString *)dequeue;              // Remove and return the string at the front
- (NSUInteger)size;                 // Get the number of elements in the buffer
- (BOOL)isEmpty;

@end
