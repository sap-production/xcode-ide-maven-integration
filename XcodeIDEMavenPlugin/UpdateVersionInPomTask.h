//
//  UpdatePomTask.h
//  XcodeIDEMavenPlugin
//
//  Created by Holl, Marcus on 11/8/12.
//  Copyright (c) 2012 SAP AG. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MyMenuItem.h"

@interface UpdateVersionInPomTask : NSObject

-(void)updateVersionInAllPoms:(MyMenuItem *) menuItem;
-(void)updateVersionInPom:(MyMenuItem *) menuItem;

@end
