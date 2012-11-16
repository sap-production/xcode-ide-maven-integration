//
//  Task.h
//  XcodeIDEMavenPlugin
//
//  Created by Holl, Marcus on 11/9/12.
//  Copyright (c) 2012 SAP AG. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "InitializeConfiguration.h"

@interface Task : NSObject
- (NSTextView *)findConsoleAndActivate;
- (NSTask *)taskWithName:(NSString *)name Path:(NSString *)path configuration:(InitializeConfiguration *)configuration;
@end
