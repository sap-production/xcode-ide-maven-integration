//
//  MavenMenuBuilder.m
//  XcodeIDEMavenPlugin
//
//  Created by Holl, Marcus on 10/30/12.
//  Copyright (c) 2012 SAP AG. All rights reserved.
//

#import "MavenMenuBuilder.h"
#import "MyMenuItem.h"

@interface MavenMenuBuilder ()

@property (retain) NSString *title;
@property (retain) Class menuItemClass;

@property (retain) NSMutableArray *items;

@end


@implementation MavenMenuBuilder

- (id)initWithTitle:(NSString *)title menuItemClass:(Class)menuItemClass {
    self = [super init];
    if (self) {
        self.items = [NSMutableArray array];
        self.title = title;
        self.menuItemClass = menuItemClass;
    }
    return self;
}

- (id)addMenuItemWithTitle:(NSString *)title
                       keyEquivalent:(NSString *)keyEquivalent
           keyEquivalentModifierMask:(NSUInteger)keyEquivalentModifierMask
                              target:(id)target
                              action:(SEL)action {
    NSMenuItem *item = [[self.menuItemClass alloc] initWithTitle:title
                                                          action:nil
                                                   keyEquivalent:@""];
    item.keyEquivalent = keyEquivalent;
    item.keyEquivalentModifierMask = keyEquivalentModifierMask;
    item.target = target;
    item.action = action;
    [self.items addObject:item];
    return item;
}

- (id)addAlternateMenuItemWithTitle:(NSString *)title
                                       target:(id)target
                             action:(SEL)action {
    NSMenuItem *lastItem = self.items[self.items.count-1];
    NSMenuItem *item = [self addMenuItemWithTitle:title
                                    keyEquivalent:lastItem.keyEquivalent
                        keyEquivalentModifierMask:lastItem.keyEquivalentModifierMask | NSAlternateKeyMask
                                           target:target
                                           action:action];
    item.alternate = YES;
    return item;
}

- (id)addSeparator {
    NSMenuItem *item = [NSMenuItem separatorItem];
    [self.items addObject:item];
    return item;
}

- (MavenMenuBuilder *)addSubMenuWithTitle:(NSString *)title {
    MavenMenuBuilder *builder = [[self.class alloc] initWithTitle:title menuItemClass:self.menuItemClass];
    [self.items addObject:builder];
    return builder;
}

- (NSMenuItem *)build {
    NSMenuItem *item = [[self.menuItemClass alloc] initWithTitle:self.title
                                                          action:nil
                                                   keyEquivalent:@""];
    item.submenu = [self buildSubmenu];
    return item;
}

- (NSMenu *)buildSubmenu {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];
    for (id item in self.items) {
        if ([item isKindOfClass:self.class]) {
            MavenMenuBuilder *builder = item;
            NSMenuItem *item = [[self.menuItemClass alloc] initWithTitle:builder.title
                                                                  action:nil
                                                           keyEquivalent:@""];
            [menu addItem:item];
            item.submenu = [builder buildSubmenu];
        } else {
            [menu addItem:item];
        }
    }
    return menu;
}

@end
