//
//  ClassInspector.m
//  XcodeIDEMavenPlugin
//
//  Created by Holl, Marcus on 11/9/12.
//  Copyright (c) 2012 SAP AG. All rights reserved.
//

#import "ClassInspector.h"
#import "FileLogger.h"
#import <objc/runtime.h>

@implementation ClassInspector

- (void) inspectMethodsOfClass:(id) instance {
    
    const char* className = class_getName([instance class]);
    
    unsigned int count = 0;
    Method* methods = class_copyMethodList([instance class], &count);
    
    for(int i = 0; i < count; i++) {
        
        SEL selector = method_getName(methods[i]);
        
        const char* methodName = sel_getName(selector);
        [FileLogger log:[NSString stringWithFormat:@"Class: %@: Method: %@", [NSString stringWithCString:className encoding:NSUTF8StringEncoding], [NSString stringWithCString:methodName encoding:NSUTF8StringEncoding]]];
        
    }
    
    if(count == 0)
        [FileLogger log:[NSString stringWithFormat:@"No methods found for class %@", [NSString stringWithCString:className encoding:NSUTF8StringEncoding]]];
}

- (void) inspectPropertiesOfClass:(id) instance {
    
    const char* className = class_getName([instance class]);
    
    unsigned int count;
    objc_property_t* properties = class_copyPropertyList([instance class], &count);
    
    
    for(int i = 0; i < count; i++) {
        const char* propertyName = property_getName(properties[i]);
        [FileLogger log: [NSString stringWithFormat:@"Class: %@; Property: %@", [NSString stringWithCString:className encoding:NSUTF8StringEncoding], [NSString stringWithCString:propertyName encoding:NSUTF8StringEncoding]]];
    }
    
    if(count == 0)
        [FileLogger log:[NSString stringWithFormat:@"No properties found for class %@", [NSString stringWithCString:className encoding:NSUTF8StringEncoding]]];
    
    
}

-(BOOL) existsClass:(NSString *) name {
    
    id instance = [[NSClassFromString(name) alloc] init];
    
    if(instance) {
        [FileLogger log:[NSString stringWithFormat:@"Class %@ found.", name]];
        return YES;
    }
    
    [FileLogger log:[NSString stringWithFormat:@"Class %@ not found.", name] ];
    return NO;
}

@end
