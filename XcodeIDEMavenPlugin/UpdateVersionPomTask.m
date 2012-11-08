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

-(void)updateVersionInAllPoms:(MyMenuItem *) menuItem {
    XcodeConsole *console = [[XcodeConsole alloc] initWithConsole:[self findConsoleAndActivate]];
    [self runUpdateVersionInPomForProjects:menuItem.xcode3Projects withConsole:console];
}

- (void)updateVersionInPom:(MyMenuItem *) menuItem {
    XcodeConsole *console = [[XcodeConsole alloc] initWithConsole:[self findConsoleAndActivate]];
    [self runUpdateVersionInPomForProject:menuItem.xcode3Projects[0] withConsole:console];
}

-(void)runUpdateVersionInPomForProjects:(NSArray *)xcode3Projects withConsole:(XcodeConsole *)console {
    
    for(id xcode3Project in xcode3Projects) {
        [self runUpdateVersionInPomForProject:xcode3Project withConsole:console];
    }
}

- (void)runUpdateVersionInPomForProject:(id) xcode3Project withConsole:(XcodeConsole*)console {
    
    [FileLogger log: [NSString stringWithFormat:@"Update version in Pom triggered for project: %@", [xcode3Project description]]];
    
    NSString *mavenProjectPath = [SAPXcodeMavenPlugin getMavenProjectRootDirectory:xcode3Project];
    
    if (![NSFileManager.defaultManager fileExistsAtPath:[mavenProjectPath stringByAppendingPathComponent:@"pom.xml"]]) {
        [console appendText:[NSString stringWithFormat:@"pom.xml not found at %@\n", mavenProjectPath] color:NSColor.redColor];
        return;
    }
    
    NSTask *task = [self updateVersionTaskWithPath:mavenProjectPath];
    RunOperation *operation = [[RunOperation alloc] initWithTask:task];
    operation.xcodeConsole = console;
    [self.initializeQueue addOperation:operation];
    
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

- (NSTextView *)findConsoleAndActivate {
    Class consoleTextViewClass = objc_getClass("IDEConsoleTextView");
    NSTextView *console = (NSTextView *)[self findView:consoleTextViewClass inView:NSApplication.sharedApplication.mainWindow.contentView];
    
    if (console) {
        NSWindow *window = NSApplication.sharedApplication.keyWindow;
        if ([window isKindOfClass:objc_getClass("IDEWorkspaceWindow")]) {
            if ([window.windowController isKindOfClass:NSClassFromString(@"IDEWorkspaceWindowController")]) {
                id editorArea = [window.windowController valueForKey:@"editorArea"];
                [editorArea performSelector:@selector(activateConsole:) withObject:self];
            }
        }
    }
    
    return console;
}

- (NSView *)findView:(Class)consoleClass inView:(NSView *)view {
    if ([view isKindOfClass:consoleClass]) {
        return view;
    }
    
    for (NSView *v in view.subviews) {
        NSView *result = [self findView:consoleClass inView:v];
        if (result) {
            return result;
        }
    }
    return nil;
}

@end
