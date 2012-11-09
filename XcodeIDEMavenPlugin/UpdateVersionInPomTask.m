//
//  UpdatePomTask.m
//  XcodeIDEMavenPlugin
//
//  Created by Holl, Marcus on 11/8/12.
//  Copyright (c) 2012 SAP AG. All rights reserved.
//

#import <objc/runtime.h>
#import "UpdateVersionInPomTask.h"
#import "RunOperation.h"
#import "FileLogger.h"
#import "SAPXcodeMavenPlugin.h"


@interface  UpdateVersionInPomTask()
@property (retain) NSOperationQueue *initializeQueue;
@end

@implementation UpdateVersionInPomTask

- (UpdateVersionInPomTask *)initWithQueue:(NSOperationQueue *)queue {
    
    self = [super init];
    
    if(self)
    {
        self.initializeQueue = queue;
    }
    
    return self;
}

- (void)updateVersionInPom:(MyMenuItem *) menuItem {
    XcodeConsole *console = [[XcodeConsole alloc] initWithConsole:[self findConsoleAndActivate]];
    [self runUpdateVersionInPomForProjects:menuItem.xcode3Projects withConsole:console];
}

- (void)runUpdateVersionInPomForProjects:(NSArray *)xcode3Projects withConsole:(XcodeConsole *)console {
    
    for(id xcode3Project in xcode3Projects) {
        [self runUpdateVersionInPomForProject:xcode3Project withConsole:console];
    }
}

- (void)runUpdateVersionInPomForProject:(id) xcode3Project withConsole:(XcodeConsole*)console {
    
    [FileLogger log: [NSString stringWithFormat:@"Trigger update of version in pom for project: %@.", [xcode3Project description]]];
    
    NSString *mavenProjectPath = [SAPXcodeMavenPlugin getMavenProjectRootDirectory:xcode3Project];
    
    if (![NSFileManager.defaultManager fileExistsAtPath:[mavenProjectPath stringByAppendingPathComponent:@"pom.xml"]]) {
        NSString *errorMessage = [NSString stringWithFormat:@"pom.xml not found at %@.", mavenProjectPath];
        [FileLogger log:errorMessage];
        [console appendText:[errorMessage stringByAppendingString:@"\n"] color:NSColor.redColor];
        return;
    }
    
    NSTask *task = [self updateVersionTaskWithPath:mavenProjectPath];
    RunOperation *operation = [[RunOperation alloc] initWithTask:task];
    operation.xcodeConsole = console;
    [self.initializeQueue addOperation:operation];
    [FileLogger log:[NSString stringWithFormat:@"Update of version in pom triggered for project %@.", [xcode3Project description]]];
    
}

- (NSTask *)updateVersionTaskWithPath:(NSString *)path {
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/mvn";
    task.currentDirectoryPath = path;
    
    NSMutableArray *arguments = [NSMutableArray arrayWithCapacity:8];
    
    NSString *pluginGAV = @"com.sap.prd.mobile.ios.mios:xcode-maven-plugin:1.6.1-SNAPSHOT";
    
    [arguments addObject: [[NSString alloc] initWithFormat:@"%@:%@", pluginGAV, @"check-prerequisites"]];
    [arguments addObject: [[NSString alloc] initWithFormat:@"%@:%@", pluginGAV, @"change-artifact-id"]];
    [arguments addObject: [[NSString alloc] initWithFormat:@"%@:%@", pluginGAV, @"set-default-configuration"]];
    [arguments addObject: [[NSString alloc] initWithFormat:@"%@:%@", pluginGAV, @"xcode-project-validate"]];
    [arguments addObject: [[NSString alloc] initWithFormat:@"%@:%@", pluginGAV, @"prepare-xcode-build"]];
    [arguments addObject: [[NSString alloc] initWithFormat:@"%@:%@", pluginGAV, @"copy-sources"]];
    [arguments addObject: [[NSString alloc] initWithFormat:@"%@:%@", pluginGAV, @"save-build-settings"]];
    [arguments addObject: [[NSString alloc] initWithFormat:@"%@:%@", pluginGAV, @"update-version-in-pom"]];
    
    task.arguments = arguments;
    
    return task;
}

@end
