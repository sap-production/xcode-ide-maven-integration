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

#import "RunInitializeOperation.h"

@interface RunInitializeOperation ()

@property (retain) id xcode3Project;
@property (retain) InitializeConfiguration *configuration;

@property (retain) NSTask *initializeTask;
@property (retain) id initializeTaskStandardOutDataAvailableObserver;
@property (retain) id initializeTaskStandardErrorDataAvailableObserver;
@property (retain) id initializeTaskTerminationObserver;

@end


@implementation RunInitializeOperation

#pragma mark -
#pragma mark NSOperation

- (id)initWithProject:(id)xcode3Project configuration:(InitializeConfiguration *)configuration {
    if (self = [super init]) {
        self.xcode3Project = xcode3Project;
        self.configuration = configuration;
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
        [self requestCancellation];
    } else {
        [self runInitialize];
    }
}

- (void)requestCancellation {
    self.isExecuting = NO;
    self.isFinished = YES;
}

#pragma mark -
#pragma mark NSTask

- (void)runInitialize {
    NSString *path = [[self.xcode3Project valueForKey:@"itemBaseFilePath"] valueForKey:@"pathString"];
    path = [path stringByAppendingPathComponent:@"../.."];
    NSString *pom = [path stringByAppendingPathComponent:@"pom.xml"];
    if (![NSFileManager.defaultManager fileExistsAtPath:pom]) {
        [self.xcodeConsole appendText:[NSString stringWithFormat:@"pom.xml not found at %@\n", pom] color:NSColor.redColor];
        [self requestCancellation];
        return;
    }

    @try {
        self.initializeTask = [[NSTask alloc] init];
        self.initializeTask.launchPath = @"/usr/bin/mvn";
        self.initializeTask.currentDirectoryPath = path;
        NSMutableArray *args = [@[@"-B"] mutableCopy];
        if (self.configuration) {
            if (self.configuration.debug) {
                [args addObject:@"-X"];
            }
            if (self.configuration.forceUpdate) {
                [args addObject:@"-U"];
            }
            if (self.configuration.clean) {
                [args addObject:@"clean"];
            }
        }
        [args addObject:@"initialize"];
        self.initializeTask.arguments = args;
        NSPipe *o = NSPipe.pipe;
        self.initializeTask.standardOutput = o;
        NSPipe *e = NSPipe.pipe;
        self.initializeTask.standardError = e;
        NSFileHandle *of = o.fileHandleForReading;
        NSFileHandle *ef = e.fileHandleForReading;

        __block NSMutableString *outBuffer = [NSMutableString string];
        __block NSMutableString *errBuffer = [NSMutableString string];

        self.initializeTaskStandardOutDataAvailableObserver = [NSNotificationCenter.defaultCenter addObserverForName:NSFileHandleDataAvailableNotification
                                                                                                              object:of queue:NSOperationQueue.mainQueue
                                                                                                          usingBlock:^(NSNotification *notification) {
                                                                                                              NSFileHandle *fileHandle = notification.object;
                                                                                                              NSString *data = [[NSString alloc] initWithData:fileHandle.availableData encoding:NSUTF8StringEncoding];
                                                                                                              if (data) {
                                                                                                                  [outBuffer appendString:data];
                                                                                                                  [fileHandle waitForDataInBackgroundAndNotify];
                                                                                                              }

                                                                                                              outBuffer = [self writeTaskBuffer:outBuffer];
                                                                                                          }];

        self.initializeTaskStandardErrorDataAvailableObserver = [NSNotificationCenter.defaultCenter addObserverForName:NSFileHandleDataAvailableNotification
                                                                                                                object:ef queue:NSOperationQueue.mainQueue
                                                                                                            usingBlock:^(NSNotification *notification) {
                                                                                                                NSFileHandle *fileHandle = notification.object;
                                                                                                                NSString *data = [[NSString alloc] initWithData:fileHandle.availableData encoding:NSUTF8StringEncoding];
                                                                                                                if (data) {
                                                                                                                    [errBuffer appendString:data];
                                                                                                                    [fileHandle waitForDataInBackgroundAndNotify];
                                                                                                                }

                                                                                                                errBuffer = [self writeTaskBuffer:errBuffer];
                                                                                                            }];

        self.initializeTaskTerminationObserver = [NSNotificationCenter.defaultCenter addObserverForName:NSTaskDidTerminateNotification
                                                                                                 object:self.initializeTask queue:NSOperationQueue.mainQueue
                                                                                             usingBlock:^(NSNotification *notification) {
                                                                                                 [NSNotificationCenter.defaultCenter removeObserver:self.initializeTaskStandardOutDataAvailableObserver];
                                                                                                 [NSNotificationCenter.defaultCenter removeObserver:self.initializeTaskStandardErrorDataAvailableObserver];
                                                                                                 [NSNotificationCenter.defaultCenter removeObserver:self.initializeTaskTerminationObserver];
                                                                                                 self.initializeTaskStandardOutDataAvailableObserver = nil;
                                                                                                 self.initializeTaskStandardErrorDataAvailableObserver = nil;
                                                                                                 self.initializeTaskTerminationObserver = nil;

                                                                                                 [self appendLine:outBuffer];
                                                                                                 [self appendLine:errBuffer];

                                                                                                 self.initializeTask = nil;

                                                                                                 self.isExecuting = NO;
                                                                                                 self.isFinished = YES;
                                                                                             }];

        [of waitForDataInBackgroundAndNotify];
        [ef waitForDataInBackgroundAndNotify];
        
        [self.xcodeConsole appendText:[NSString stringWithFormat:@"%@ %@\n\n", self.initializeTask.launchPath, [self.initializeTask.arguments componentsJoinedByString:@" "]]];
        [self.initializeTask launch];
    }
    @catch (NSException *exception) {
        [self.xcodeConsole appendText:exception.description color:NSColor.redColor];
        [self.xcodeConsole appendText:@"\n"];
        self.isExecuting = NO;
        self.isFinished = YES;
    }
}

- (NSMutableString *)writeTaskBuffer:(NSMutableString *)buffer {
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

@end
