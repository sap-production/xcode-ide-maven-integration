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

@interface InitializeTask()
@property (retain) NSOperationQueue *initializeQueue;
@property (retain) XcodeConsole *console;
@property (retain) InitializeWindowController *initializeWindowController;

@end

@implementation InitializeTask

- (InitializeTask *) initWithConsole:(XcodeConsole *)console Queue:(NSOperationQueue *)queue initializeWindowController:(InitializeWindowController *) initializeWindowController {
    
    self = [super init];
    
    if(self) {
        self.initializeQueue = queue;
        self.console = console;
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
        NSString *mavenProjectRootDirectory = [SAPXcodeMavenPlugin getMavenProjectRootDirectory:xcode3Project];
        NSString *pom = [SAPXcodeMavenPlugin getPomFilePath:xcode3Project];
        if (![NSFileManager.defaultManager fileExistsAtPath:pom]) {
            [self.console appendText:[NSString stringWithFormat:@"pom.xml not found at %@\n", pom] color:NSColor.redColor];
        } else {
            NSTask *task = [self initializeTaskWithPath:mavenProjectRootDirectory configuration:configuration];
            RunOperation *operation = [[RunOperation alloc] initWithTask:task];
            operation.xcodeConsole = self.console;
            [self.initializeQueue addOperation:operation];
        }
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

@end
