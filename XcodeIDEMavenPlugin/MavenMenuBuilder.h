//
//  MavenMenuBuilder.h
//  XcodeIDEMavenPlugin
//
//  Created by Holl, Marcus on 10/30/12.
//  Copyright (c) 2012 SAP AG. All rights reserved.
//

@interface MavenMenuBuilder : NSObject

- (id)initWithTitle:(NSString *)title menuItemClass:(Class)menuItemClass;

- (id)addMenuItemWithTitle:(NSString *)title
             keyEquivalent:(NSString *)keyEquivalent
 keyEquivalentModifierMask:(NSUInteger)keyEquivalentModifierMask
                    target:(id)target
                    action:(SEL)action;
- (id)addAlternateMenuItemWithTitle:(NSString *)title
                             target:(id)target
                             action:(SEL)action;
- (id)addSeparator;
- (MavenMenuBuilder *)addSubMenuWithTitle:(NSString *)title;

- (id)build;

@end
