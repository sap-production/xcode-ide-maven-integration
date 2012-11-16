//
//  Task.m
//  XcodeIDEMavenPlugin
//
//  Created by Holl, Marcus on 11/9/12.
//  Copyright (c) 2012 SAP AG. All rights reserved.
//

#import "Task.h"
#import <objc/runtime.h>

@implementation Task
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

- (NSTask *)taskWithName:(NSString *)name Path:(NSString *)path configuration:(InitializeConfiguration *)configuration {
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/mvn";
    task.currentDirectoryPath = path;
    NSMutableArray *args = [@[@"-B"] mutableCopy];
    if (configuration) {
        if (configuration.debug) {
            [args addObject:@"-X"];
        }
        if (configuration.forceUpdate) {
            [args addObject:@"-U"];
        }
        if (configuration.clean) {
            [args addObject:@"clean"];
        }
    }
    [args addObject:name];
    task.arguments = args;
    return task;
}

@end
