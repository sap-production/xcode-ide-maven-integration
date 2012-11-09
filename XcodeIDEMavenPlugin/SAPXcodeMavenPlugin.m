/*
 * #%L
 * xcode-maven-plugin
 * %%
 * Copyright (C) 2012 SAP AG
 * %%
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 * #L%
 */

#import "SAPXcodeMavenPlugin.h"
#import <objc/runtime.h>
#import "MyMenuItem.h"
#import "InitializeWindowController.h"
#import "RunOperation.h"
#import "MavenMenuBuilder.h"
#import "FileLogger.h"
#import "UpdateVersionInPomTask.h"
#import "XcodeConsole.h"
#import "InitializeTask.h"

@interface SAPXcodeMavenPlugin ()

@property (retain) NSOperationQueue *initializeQueue;

@property (retain) id activeWorkspace;
@property (retain) NSMenuItem *xcodeMavenPluginSeparatorItem;
@property (retain) NSMenuItem *xcodeMavenPluginItem;

@property (retain) InitializeWindowController *initializeWindowController;

@end


@implementation SAPXcodeMavenPlugin

static SAPXcodeMavenPlugin *plugin;

+ (id)sharedSAPXcodeMavenPlugin {
	return plugin;
}

+ (void)pluginDidLoad:(NSBundle *)bundle {
	plugin = [[self alloc] initWithBundle:bundle];
}


+(NSString *) getMavenProjectRootDirectory:(id) xcode3Project {
    
    if(! xcode3Project)
        return nil;
    
    NSString *path = [[xcode3Project valueForKey:@"itemBaseFilePath"] valueForKey:@"pathString"];
    return [path stringByAppendingPathComponent:@"../.."];
}

+(NSString *) getPomFilePath:(id) xcode3Project {
    return [[SAPXcodeMavenPlugin getMavenProjectRootDirectory:xcode3Project] stringByAppendingPathComponent:@"pom.xml"];
}

- (id)initWithBundle:(NSBundle *)bundle {
    self = [super init];
	if (self) {
        self.initializeQueue = [[NSOperationQueue alloc] init];
        self.initializeQueue.maxConcurrentOperationCount = 1;
        
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(buildProductsLocationDidChange:)
                                                   name:@"IDEWorkspaceBuildProductsLocationDidChangeNotification"
                                                 object:nil];
        
        [NSApplication.sharedApplication addObserver:self
                                          forKeyPath:@"mainWindow"
                                             options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionOld
                                             context:NULL];
	}
	return self;
}

- (void)buildProductsLocationDidChange:(NSNotification *)notification {
    [self updateMainMenu];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    @try {
        if ([object isKindOfClass:NSApplication.class] && [keyPath isEqualToString:@"mainWindow"] && change[NSKeyValueChangeOldKey] != NSApplication.sharedApplication.mainWindow && NSApplication.sharedApplication.mainWindow) {
            [self updateActiveWorkspace];
        } else if ([keyPath isEqualToString:@"activeRunContext"]) {
            [self updateMainMenu];
        }
    }
    @catch (NSException *exception) {
        // TODO log
    }
}

- (void)updateActiveWorkspace {
    id newWorkspace = [self workspaceFromWindow:NSApplication.sharedApplication.keyWindow];
    if (newWorkspace != self.activeWorkspace) {
        if (self.activeWorkspace) {
            id runContextManager = [self.activeWorkspace valueForKey:@"runContextManager"];
            @try {
                [runContextManager removeObserver:self forKeyPath:@"activeRunContext"];
            }
            @catch (NSException *exception) {
                // do nothing
            }
        }
        
        self.activeWorkspace = newWorkspace;
        
        if (self.activeWorkspace) {
            id runContextManager = [self.activeWorkspace valueForKey:@"runContextManager"];
            if (runContextManager) {
                [runContextManager addObserver:self forKeyPath:@"activeRunContext" options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionOld context:NULL];
            }
        }
    }
}

- (id)workspaceFromWindow:(NSWindow *)window {
	if ([window isKindOfClass:objc_getClass("IDEWorkspaceWindow")]) {
        if ([window.windowController isKindOfClass:NSClassFromString(@"IDEWorkspaceWindowController")]) {
            return [window.windowController valueForKey:@"workspace"];
        }
    }
    return nil;
}


-(void)cleanupProductMenu:(NSMenu *) productMenu {
    
    if(self.xcodeMavenPluginSeparatorItem) {
        [productMenu removeItem:self.xcodeMavenPluginSeparatorItem];
        self.xcodeMavenPluginSeparatorItem = nil;
        [FileLogger log:@"Old separator item removed from product menu."];
    }
    if (self.xcodeMavenPluginItem) {
        [productMenu removeItem:self.xcodeMavenPluginItem];
        self.xcodeMavenPluginItem = nil;
        [FileLogger log:@"Old Plugin entry removed from product menu."];
    }
    
}

- (void)updateMainMenu {
    
    NSMenu *menu = [NSApp mainMenu];
    
    [FileLogger log:@"Updating main menu ..."];
    
    for (NSMenuItem *item in menu.itemArray) {
        
        if (![item.title isEqualToString:@"Product"])
            continue;
        
        [FileLogger log:@"Product menu found."];
        
        NSMenu *productMenu = item.submenu;
        
        [self cleanupProductMenu:productMenu];
        
        NSArray *activeProjects = self.activeWorkspace ? [self activeProjectsFromWorkspace:self.activeWorkspace] : nil;
        
        MavenMenuBuilder *builder = [[MavenMenuBuilder alloc] initWithTitle:@"Xcode Maven Plugin" menuItemClass:MyMenuItem.class];
        
        bool atLeastOnePomFileFound = false;
        
        if (activeProjects.count == 1) {
                        
            [FileLogger log: [NSString stringWithFormat:@"Project found: %@", [activeProjects[0] description]]];
            
            NSString *pomFilePath = [SAPXcodeMavenPlugin getPomFilePath:activeProjects[0]];
            [FileLogger log:[@"Single active project found. Pom file path is: " stringByAppendingString:pomFilePath]];
            
            atLeastOnePomFileFound = atLeastOnePomFileFound | [[NSFileManager defaultManager] isReadableFileAtPath:pomFilePath];
            
            MyMenuItem *initializeItem = [builder addMenuItemWithTitle:@"Initialize"
                                                         keyEquivalent:@"i"
                                             keyEquivalentModifierMask:NSCommandKeyMask | NSControlKeyMask | NSShiftKeyMask
                                                                target:self action:@selector(initialize:)];
            initializeItem.xcode3Projects = activeProjects;
            
            MyMenuItem *initializeItemAdvanced = [builder addAlternateMenuItemWithTitle:@"Initialize..."
                                                                                 target:self
                                                                                 action:@selector(initializeAdvanced:)];
            initializeItemAdvanced.xcode3Projects = activeProjects;
            
            if([self isApp:activeProjects[0]]) {
            
                MyMenuItem *updatePomMenuItem = [builder addMenuItemWithTitle:@"Update Version in Pom." keyEquivalent:@"" keyEquivalentModifierMask:NSCommandKeyMask | NSControlKeyMask | NSShiftKeyMask target:self action:@selector(updateVersionInPom:)];
            
                updatePomMenuItem.xcode3Projects = activeProjects;
                [FileLogger log:@"\"Update Pom\" menu item added."];
            }
            
            
        } else {
            
            [FileLogger log: [NSString stringWithFormat:@"%ld active projects found.", activeProjects.count]];
            
            BOOL applicationProjectFound = NO;
            
            for(id activeProject in activeProjects) {
                if([self isApp:activeProject]) {
                    applicationProjectFound = YES;
                    break;
                }
            }
            
            MavenMenuBuilder *initializeChild = [builder addSubMenuWithTitle:@"Fetch Libs"];
            MavenMenuBuilder *updatePomChild = nil;
            
            if(applicationProjectFound)
                updatePomChild = [builder addSubMenuWithTitle:@"Update Version In Pom"];
            
            int i = 0;
            
            for(id activeProject in activeProjects) {
                
                i++;
                
                NSString *pomFilePath = [SAPXcodeMavenPlugin getPomFilePath:activeProjects[0]];
                [FileLogger log:[@"Pom file path is: " stringByAppendingString:pomFilePath]];
                atLeastOnePomFileFound = atLeastOnePomFileFound | [[NSFileManager defaultManager] isReadableFileAtPath:pomFilePath];
                
                NSString *projectName = [activeProject valueForKey:@"name"];
                
                NSString *keyEquivalentInitialize = ((i == activeProjects.count) ? @"i" : @"");
                
                MyMenuItem *initializeItem = [initializeChild addMenuItemWithTitle:projectName keyEquivalent:keyEquivalentInitialize keyEquivalentModifierMask:NSCommandKeyMask | NSControlKeyMask | NSShiftKeyMask target:self action:@selector(initialize:)];
                
                initializeItem.xcode3Projects = @[activeProject];

                NSString *keyEquivalentUpdatePom = ((i == activeProjects.count) ? @"u" : @"");
                
                if(updatePomChild && [self isApp:activeProject]) {
                
                    MyMenuItem *updatePomItem = [updatePomChild addMenuItemWithTitle:projectName keyEquivalent:keyEquivalentUpdatePom keyEquivalentModifierMask:NSCommandKeyMask | NSControlKeyMask | NSShiftKeyMask target:self action:@selector(updateVersionInPom:)];
                
                    updatePomItem.xcode3Projects = @[activeProject];
                }
            }
            
            MyMenuItem *initializeAllItem = [builder addMenuItemWithTitle:@"Fetch Libs For All Projects"
                                                         keyEquivalent:@"a"
                                             keyEquivalentModifierMask:NSCommandKeyMask | NSControlKeyMask | NSShiftKeyMask
                                                                target:self action:@selector(initialize:)];
            initializeAllItem.xcode3Projects = activeProjects;
            
            MyMenuItem *initializeItemAdvanced = [builder addAlternateMenuItemWithTitle:@"Initialize All"
                                                                                 target:self action:@selector(initializeAdvanced:)];
            
            initializeItemAdvanced.xcode3Projects = activeProjects;
            

            MyMenuItem *updateAllPomsItem = [builder addMenuItemWithTitle:@"Update Version In All Poms"
                                                            keyEquivalent:@"u"
                                                keyEquivalentModifierMask:NSCommandKeyMask | NSControlKeyMask | NSShiftKeyMask
                                                                   target:self action:@selector(updateVersionInPom:)];
         
            NSArray *applicationProjects = [self getApplicationProjects:activeProjects];
            
            updateAllPomsItem.xcode3Projects = applicationProjects;

        }
        
        if(atLeastOnePomFileFound) {
            self.xcodeMavenPluginSeparatorItem = NSMenuItem.separatorItem;
            [productMenu addItem:self.xcodeMavenPluginSeparatorItem];
            self.xcodeMavenPluginItem = [builder build];
            [productMenu addItem:self.xcodeMavenPluginItem];
        } else {
            [FileLogger log:@"Xcode Menu item not added to productMenu since no pom files has been found in the involved projects."];
        }
    }
}

- (id)invokeSelector:(SEL) selector onInstance:(id) instance withParameters:(NSArray *) params {
    
    NSMethodSignature *signature = [instance methodSignatureForSelector:selector];
    
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    
    [invocation setTarget:instance];
    [invocation setSelector:selector];
        
    if(params) {
        for(int i = 0; i < [params count]; i++) {
            [invocation setArgument:[params objectAtIndex:i] atIndex:i+2]; // 2 --> skip self and cmd
        }
    }
    
    [invocation invoke];
    
    id result;
    [invocation getReturnValue:&result];
    return result;
}

- (BOOL) isApp:(id)xcode3Project {
    
    id pbxProject = [xcode3Project valueForKey:@"pbxProject"];
    id activeTarget = [self invokeSelector:@selector(activeTarget) onInstance:pbxProject withParameters:nil];
    id infoPlistFilePath = [self invokeSelector:@selector(infoPlistFilePath) onInstance:activeTarget withParameters:nil];
    
    return (infoPlistFilePath) ? YES : NO;
}

- (NSArray *) getApplicationProjects:(NSArray *) xcode3Projects  {
    
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:0];
    
    for(id xcode3Project in xcode3Projects) {
        if([self isApp:xcode3Project]) {
            [result addObject:xcode3Project];
        }
    }
    
    return result;
}


- (NSArray *)activeProjectsFromWorkspace:(id)workspace {
    id runContextManager = [workspace valueForKey:@"runContextManager"];
    id activeScheme = [runContextManager valueForKey:@"activeRunContext"];
    id buildSchemaAction = [activeScheme valueForKey:@"buildSchemeAction"];
    id buildActionEntries = [buildSchemaAction valueForKey:@"buildActionEntries"];
    NSMutableArray *projects = [NSMutableArray array];
    for (id buildActionEntry in buildActionEntries) {
        id buildableReference = [buildActionEntry valueForKey:@"buildableReference"];
        id xcode3Project = [buildableReference valueForKey:@"referencedContainer"];
        if(!xcode3Project) {
            continue;
        }
        
        if (![projects containsObject:xcode3Project]) {
            [projects addObject:xcode3Project];
        }
    }
    return projects;
}

- (void)initialize:(MyMenuItem *)menuItem {
    [[self getInitializeTask] initialize:menuItem];
}

- (void)initializeAdvanced:(MyMenuItem *)menuItem {
    [[self getInitializeTask] initializeAdvanced:menuItem];
}

-(InitializeTask *)getInitializeTask {
    return [[InitializeTask alloc] initWithQueue:self.initializeQueue initializeWindowController:self.initializeWindowController];
    
}

- (void)updateVersionInPom:(MyMenuItem *) menuItem {
    [[self getUpdateVersionInPomTask] updateVersionInPom:menuItem];
}

-(UpdateVersionInPomTask *)getUpdateVersionInPomTask {
    return [[UpdateVersionInPomTask alloc] initWithQueue:self.initializeQueue];
}

@end
