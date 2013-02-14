//
//  ClassInspector.h
//  XcodeIDEMavenPlugin
//
//  Created by Holl, Marcus on 11/9/12.
//  Copyright (c) 2012 SAP AG. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ClassInspector : NSObject
- (void) inspectMethodsOfClass:(id) instance;
- (void) inspectPropertiesOfClass:(id) instance;
- (BOOL) existsClass:(NSString *) name;
@end
