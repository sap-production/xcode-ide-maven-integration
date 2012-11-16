//
//  InstallTask.h
//  XcodeIDEMavenPlugin
//
//  Created by Holl, Marcus on 11/16/12.
//  Copyright (c) 2012 SAP AG. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "InitializeWindowController.h"
#import "MyMenuItem.h"
#import "Task.h"

@interface InstallTask : Task
- (InstallTask *) initWithQueue:(NSOperationQueue *)queue initializeWindowController:(InitializeWindowController *) initializeWindowController;
- (void)install:(MyMenuItem *)menuItem;
- (void)installAdvanced:(MyMenuItem *)menuItem;
@end
