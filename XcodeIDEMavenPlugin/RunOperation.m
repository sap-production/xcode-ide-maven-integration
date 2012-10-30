/*
 * #%L
 * xcode-maven-plugin
 * %%
 * Copyright (C) 2012 SAP AG
 * %%
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 * #L%
 */

#import "RunOperation.h"

@interface RunOperation ()

@property (retain) NSTask *task;
@property (retain) id taskStandardOutDataAvailableObserver;
@property (retain) id taskStandardErrorDataAvailableObserver;
@property (retain) id taskTerminationObserver;

@end


@implementation RunOperation

#pragma mark -
#pragma mark NSOperation

- (id)initWithTask:(NSTask *)task {
    self = [super init];
    if(self) {
        self.task = task;
    }
    return self;
}

- (BOOL)isExecuting {
    return isExecuting;
}

- (void)setIsExecuting:(BOOL)_isExecuting {
    [self willChangeValueForKey:@"isExecuting"];
    isExecuting = _isExecuting;
    [self didChangeValueForKey:@"isExecuting"];
}

- (BOOL)isFinished {
    return isFinished;
}

- (void)setIsFinished:(BOOL)_isFinished {
    [self willChangeValueForKey:@"isFinished"];
    isFinished = _isFinished;
    [self didChangeValueForKey:@"isFinished"];
}

- (void)start {
    if (self.isCancelled) {
        self.isFinished = YES;
        return;
    }

    if (!NSThread.isMainThread) {
        [self performSelector:@selector(start) onThread:NSThread.mainThread withObject:nil waitUntilDone:NO];
        return;
    }

    self.isExecuting = YES;
    [self main];
}

- (void)main {
    if (self.isCancelled) {
        self.isExecuting = NO;
        self.isFinished = YES;
    } else {
        [self runOperation];
    }
}

#pragma mark -
#pragma mark NSTask

- (void)runOperation {
    @try {
        NSPipe *standardOutputPipe = NSPipe.pipe;
        self.task.standardOutput = standardOutputPipe;
        NSPipe *standardErrorPipe = NSPipe.pipe;
        self.task.standardError = standardErrorPipe;
        NSFileHandle *standardOutputFileHandle = standardOutputPipe.fileHandleForReading;
        NSFileHandle *standardErrorFileHandle = standardErrorPipe.fileHandleForReading;
        
        __block NSMutableString *standardOutputBuffer = [NSMutableString string];
        __block NSMutableString *standardErrorBuffer = [NSMutableString string];
        
        self.taskStandardOutDataAvailableObserver = [NSNotificationCenter.defaultCenter addObserverForName:NSFileHandleDataAvailableNotification
                                                                                                    object:standardOutputFileHandle queue:NSOperationQueue.mainQueue
                                                                                                usingBlock:^(NSNotification *notification) {
                                                                                                    NSFileHandle *fileHandle = notification.object;
                                                                                                    NSString *data = [[NSString alloc] initWithData:fileHandle.availableData encoding:NSUTF8StringEncoding];
                                                                                                    if (data.length > 0) {
                                                                                                        [standardOutputBuffer appendString:data];
                                                                                                        [fileHandle waitForDataInBackgroundAndNotify];
                                                                                                        standardOutputBuffer = [self writePipeBuffer:standardOutputBuffer];
                                                                                                    } else {
                                                                                                        [self appendLine:standardOutputBuffer];
                                                                                                        [NSNotificationCenter.defaultCenter removeObserver:self.taskStandardOutDataAvailableObserver];
                                                                                                        self.taskStandardOutDataAvailableObserver = nil;
                                                                                                        [self checkAndSetFinished];
                                                                                                    }
                                                                                                }];
        
        self.taskStandardErrorDataAvailableObserver = [NSNotificationCenter.defaultCenter addObserverForName:NSFileHandleDataAvailableNotification
                                                                                                      object:standardErrorFileHandle queue:NSOperationQueue.mainQueue
                                                                                                  usingBlock:^(NSNotification *notification) {
                                                                                                      NSFileHandle *fileHandle = notification.object;
                                                                                                      NSString *data = [[NSString alloc] initWithData:fileHandle.availableData encoding:NSUTF8StringEncoding];
                                                                                                      if (data.length > 0) {
                                                                                                          [standardErrorBuffer appendString:data];
                                                                                                          [fileHandle waitForDataInBackgroundAndNotify];
                                                                                                          standardErrorBuffer = [self writePipeBuffer:standardErrorBuffer];
                                                                                                      } else {
                                                                                                          [self appendLine:standardErrorBuffer];
                                                                                                          [NSNotificationCenter.defaultCenter removeObserver:self.taskStandardErrorDataAvailableObserver];
                                                                                                          self.taskStandardErrorDataAvailableObserver = nil;
                                                                                                          [self checkAndSetFinished];
                                                                                                      }
                                                                                                  }];
        
        self.taskTerminationObserver = [NSNotificationCenter.defaultCenter addObserverForName:NSTaskDidTerminateNotification
                                                                                       object:self.task queue:NSOperationQueue.mainQueue
                                                                                   usingBlock:^(NSNotification *notification) {
                                                                                       [NSNotificationCenter.defaultCenter removeObserver:self.taskTerminationObserver];
                                                                                       self.taskTerminationObserver = nil;
                                                                                       self.task = nil;
                                                                                       [self checkAndSetFinished];
                                                                                   }];
        
        [standardOutputFileHandle waitForDataInBackgroundAndNotify];
        [standardErrorFileHandle waitForDataInBackgroundAndNotify];
        
        [self.xcodeConsole appendText:[NSString stringWithFormat:@"%@ %@\n\n", self.task.launchPath, [self.task.arguments componentsJoinedByString:@" "]]];
        [self.task launch];
    }
    @catch (NSException *exception) {
        [self.xcodeConsole appendText:exception.description color:NSColor.redColor];
        [self.xcodeConsole appendText:@"\n"];
        self.isExecuting = NO;
        self.isFinished = YES;
    }
}

- (NSMutableString *)writePipeBuffer:(NSMutableString *)buffer {
    NSArray *lines = [buffer componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet];
    if (lines.count > 1) {
        for (int i = 0; i < lines.count-1; i++) {
            NSString *line = lines[i];
            [self appendLine:line];
        }
        return [lines[lines.count-1] mutableCopy];
    }
    return buffer;
}

- (void)appendLine:(NSString *)line {
    if ([line hasPrefix:@"[ERROR]"]) {
        [self.xcodeConsole appendText:line color:NSColor.redColor];
    }
    else if ([line hasPrefix:@"[WARNING]"]) {
        [self.xcodeConsole appendText:line color:NSColor.orangeColor];

    }
    else if ([line hasPrefix:@"[DEBUG]"]) {
        [self.xcodeConsole appendText:line color:NSColor.grayColor];
    }
    else {
        [self.xcodeConsole appendText:line];
    }
    [self.xcodeConsole appendText:@"\n"];
}

- (void)checkAndSetFinished {
    if (self.taskStandardOutDataAvailableObserver == nil &&
        self.taskStandardErrorDataAvailableObserver == nil &&
        self.task == nil) {
        self.isExecuting = NO;
        self.isFinished = YES;
    }
}

@end
