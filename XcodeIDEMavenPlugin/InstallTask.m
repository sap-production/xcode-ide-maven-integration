//
//  InstallTask.m
//  XcodeIDEMavenPlugin
//
//  Created by Holl, Marcus on 11/16/12.
//  Copyright (c) 2012 SAP AG. All rights reserved.
//

#import "InstallTask.h"
#import "XcodeConsole.h"
#import "FileLogger.h"
#import "SAPXcodeMavenPlugin.h"
#import "RunOperation.h"

@interface InstallTask()
  @property (retain) NSOperationQueue *initializeQueue;
  @property (retain) InitializeWindowController *initializeWindowController;
@end

@implementation InstallTask

- (InstallTask *) initWithQueue:(NSOperationQueue *)queue initializeWindowController:(InitializeWindowController *) initializeWindowController {
    
    self = [super init];
    
    if(self) {
        self.initializeQueue = queue;
        self.initializeWindowController = initializeWindowController;
    }
    
    return self;
}

- (void)install:(MyMenuItem *)menuItem {
    [self runInstallForProjects:menuItem.xcode3Projects configuration:nil];
}

- (void)installAdvanced:(MyMenuItem *)menuItem {
    [self defineConfigurationAndRunInstallForProjects:menuItem.xcode3Projects];
}

- (void)defineConfigurationAndRunInstallForProjects:(NSArray *)xcode3Projects {
    self.initializeWindowController = [[InitializeWindowController alloc] initWithWindowNibName:@"InitializeWindowController"];
    self.initializeWindowController.xcode3Projects = xcode3Projects;
    self.initializeWindowController.run = ^(InitializeConfiguration *configuration) {
        [NSApp abortModal];
        [self.initializeWindowController close];
        self.initializeWindowController = nil;
        [self runInstallForProjects:xcode3Projects configuration:configuration];
    };
    self.initializeWindowController.cancel = ^{
        [NSApp abortModal];
        self.initializeWindowController = nil;
    };
    [NSApp runModalForWindow:self.initializeWindowController.window];
}

- (void)runInstallForProjects:(NSArray *)xcode3Projects configuration:(InitializeConfiguration *)configuration {
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
        
        NSTask *task = [self installTaskWithPath:mavenProjectRootDirectory configuration:configuration];
        RunOperation *operation = [[RunOperation alloc] initWithTask:task];
        operation.xcodeConsole = console;
        [self.initializeQueue addOperation:operation];
        [FileLogger log:[NSString stringWithFormat:@"Initialization triggered for project %@.", [xcode3Project description]]];
        
    }
}

- (NSTask *)installTaskWithPath:(NSString *)path configuration:(InitializeConfiguration *)configuration {
    return [self taskWithName:@"install" Path:path configuration:configuration];
}


@end
