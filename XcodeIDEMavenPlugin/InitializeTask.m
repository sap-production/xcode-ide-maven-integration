//
//  InitializeTask.m
//  XcodeIDEMavenPlugin
//
//  Created by Holl, Marcus on 11/8/12.
//  Copyright (c) 2012 SAP AG. All rights reserved.
//

#import "InitializeTask.h"
#import "SAPXcodeMavenPlugin.h"
#import "RunOperation.h"
#import "FileLogger.h"
#import <objc/runtime.h>

@interface InitializeTask()
@property (retain) NSOperationQueue *initializeQueue;
@property (retain) InitializeWindowController *initializeWindowController;

@end

@implementation InitializeTask

- (InitializeTask *) initWithQueue:(NSOperationQueue *)queue initializeWindowController:(InitializeWindowController *) initializeWindowController {
    
    self = [super init];
    
    if(self) {
        self.initializeQueue = queue;
        self.initializeWindowController = initializeWindowController;
    }
    
    return self;
}

- (void)initialize:(MyMenuItem *)menuItem {
    [self runInitializeForProjects:menuItem.xcode3Projects configuration:nil];
}

- (void)initializeAdvanced:(MyMenuItem *)menuItem {
    [self defineConfigurationAndRunInitializeForProjects:menuItem.xcode3Projects];
}

- (void)runInitializeForProjects:(NSArray *)xcode3Projects configuration:(InitializeConfiguration *)configuration {
    for (id xcode3Project in xcode3Projects) {

        XcodeConsole *console = [[XcodeConsole alloc] initWithConsole:[self findConsoleAndActivate]];
        
        [FileLogger log:[NSString stringWithFormat:@"Trigger initialize for project %@.", [xcode3Project description]]];
        
        NSString *mavenProjectRootDirectory = [SAPXcodeMavenPlugin getMavenProjectRootDirectory:xcode3Project];
        NSString *pom = [SAPXcodeMavenPlugin getPomFilePath:xcode3Project];
        
        if (![NSFileManager.defaultManager fileExistsAtPath:pom]) {

            NSString * errorMessage = [NSString stringWithFormat:@"pom.xml not found at %@.", pom];
            [FileLogger log:errorMessage];
            [console appendText:[errorMessage stringByAppendingString:@"\n"] color:NSColor.redColor];
            return;

        }

        NSTask *task = [self initializeTaskWithPath:mavenProjectRootDirectory configuration:configuration];
        RunOperation *operation = [[RunOperation alloc] initWithTask:task];
        operation.xcodeConsole = console;
        [self.initializeQueue addOperation:operation];
        [FileLogger log:[NSString stringWithFormat:@"Initialization triggered for project %@.", [xcode3Project description]]];
        
    }
}

- (void)defineConfigurationAndRunInitializeForProjects:(NSArray *)xcode3Projects {
    self.initializeWindowController = [[InitializeWindowController alloc] initWithWindowNibName:@"InitializeWindowController"];
    self.initializeWindowController.xcode3Projects = xcode3Projects;
    self.initializeWindowController.run = ^(InitializeConfiguration *configuration) {
        [NSApp abortModal];
        [self.initializeWindowController close];
        self.initializeWindowController = nil;
        [self runInitializeForProjects:xcode3Projects configuration:configuration];
    };
    self.initializeWindowController.cancel = ^{
        [NSApp abortModal];
        self.initializeWindowController = nil;
    };
    [NSApp runModalForWindow:self.initializeWindowController.window];
}

- (NSTask *)initializeTaskWithPath:(NSString *)path configuration:(InitializeConfiguration *)configuration {
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
    [args addObject:@"initialize"];
    task.arguments = args;
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
