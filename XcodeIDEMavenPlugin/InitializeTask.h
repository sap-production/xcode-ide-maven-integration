//
//  InitializeTask.h
//  XcodeIDEMavenPlugin
//
//  Created by Holl, Marcus on 11/8/12.
//  Copyright (c) 2012 SAP AG. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MyMenuItem.h"
#import "XcodeConsole.h"
#import "InitializeWindowController.h"
#import "Task.h"

@interface InitializeTask : Task
- (InitializeTask *) initWithQueue:(NSOperationQueue *)queue initializeWindowController:(InitializeWindowController *) initializeWindowController;
- (void)initialize:(MyMenuItem *)menuItem;
- (void)initializeAdvanced:(MyMenuItem *)menuItem;
@end
