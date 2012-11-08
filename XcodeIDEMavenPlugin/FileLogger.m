//
//  FileLogger.m
//  XcodeIDEMavenPlugin
//
//  Created by Holl, Marcus on 11/7/12.
//  Copyright (c) 2012 SAP AG. All rights reserved.
//

#import "FileLogger.h"

@implementation FileLogger


+(void) log:(NSString *)message {
    
    NSString *homeDirectory = NSHomeDirectory();
    
    NSString *logFilePath = [homeDirectory stringByAppendingString: @"/.xcodeMavenPluginLog.txt"];
    
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:logFilePath];
    
    if(![[NSFileManager defaultManager] fileExistsAtPath:logFilePath]) {
        [[NSFileManager defaultManager] createFileAtPath:logFilePath contents:nil attributes:nil];
    }
    
    NSString *logMessage =  [NSString stringWithFormat:@"%@: %@\n", [NSDate date], message];
    
    [fileHandle seekToEndOfFile];
    [fileHandle writeData:[logMessage dataUsingEncoding:NSUTF8StringEncoding]];
    
    free(logMessage);
    free(fileHandle);
}
@end
