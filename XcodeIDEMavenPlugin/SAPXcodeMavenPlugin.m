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
            
            NSString *pomFilePath = [SAPXcodeMavenPlugin getPomFilePath:activeProjects[0]];
            [FileLogger log:[@"Pom file path is: " stringByAppendingString:pomFilePath]];
            
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
            
            MyMenuItem *updatePomMenuItem = [builder addMenuItemWithTitle:@"Update Version in Pom." keyEquivalent:@"" keyEquivalentModifierMask:NSCommandKeyMask | NSControlKeyMask | NSShiftKeyMask target:self action:@selector(updateVersionInPom:)];
            
            updatePomMenuItem.xcode3Projects = activeProjects;
            [FileLogger log:@"\"Update Pom\" menu item added."];
            
            
        } else {
            
            MavenMenuBuilder *initializeChild = [builder addSubMenuWithTitle:@"Initialize"];
            MavenMenuBuilder *updatePomChild = [builder addSubMenuWithTitle:@"Update Pom"];
            
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
                
                MyMenuItem *updatePomItem = [updatePomChild addMenuItemWithTitle:projectName keyEquivalent:keyEquivalentUpdatePom keyEquivalentModifierMask:NSCommandKeyMask | NSControlKeyMask | NSShiftKeyMask target:self action:@selector(updateVersionInPom:)];
                
                updatePomItem.xcode3Projects = @[activeProject];

            }
            
            MyMenuItem *initializeAllItem = [builder addMenuItemWithTitle:@"Initialize All"
                                                         keyEquivalent:@"a"
                                             keyEquivalentModifierMask:NSCommandKeyMask | NSControlKeyMask | NSShiftKeyMask
                                                                target:self action:@selector(initializeAll:)];
            initializeAllItem.xcode3Projects = activeProjects;
            
            MyMenuItem *initializeItemAdvanced = [builder addAlternateMenuItemWithTitle:@"Initialize All"
                                                                                 target:self action:@selector(initializeAllAdvanced:)];
            
            initializeItemAdvanced.xcode3Projects = activeProjects;
            

            MyMenuItem *updateAllPomsItem = [builder addMenuItemWithTitle:@"Update All Poms"
                                                            keyEquivalent:@"u"
                                                keyEquivalentModifierMask:NSCommandKeyMask | NSControlKeyMask | NSShiftKeyMask
                                                                   target:self action:@selector(updateVersionInAllPoms:)];
            
            updateAllPomsItem.xcode3Projects = activeProjects;

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

- (void)initializeAdvanced:(MyMenuItem *)menuItem {
    [self defineConfigurationAndRunInitializeForProjects:menuItem.xcode3Projects];
}

- (void)defineConfigurationAndRunInitializeForProjects:(NSArray *)xcode3Projects {
    self.initializeWindowController = [[InitializeWindowController alloc] initWithWindowNibName:@"InitializeWindowController"];
    self.initializeWindowController.xcode3Projects = xcode3Projects;
    self.initializeWindowController.run = ^(InitializeConfiguration *configuration) {
        [NSApp abortModal];
        [self.initializeWindowController close];
        self.initializeWindowController = nil;
        [self runInitializeForProjects:xcode3Projects configuration:configuration];
    };
    self.initializeWindowController.cancel = ^{
        [NSApp abortModal];
        self.initializeWindowController = nil;
    };
    [NSApp runModalForWindow:self.initializeWindowController.window];
}

- (void)initialize:(MyMenuItem *)menuItem {
    [self runInitializeForProjects:menuItem.xcode3Projects configuration:nil];
}

- (void)initializeAllAdvanced:(MyMenuItem *)menuItem {
    [self defineConfigurationAndRunInitializeForProjects:menuItem.xcode3Projects];
}

- (void)initializeAll:(MyMenuItem *)menuItem {
    [self runInitializeForProjects:menuItem.xcode3Projects configuration:nil];
}

- (void)runInitializeForProjects:(NSArray *)xcode3Projects configuration:(InitializeConfiguration *)configuration {
    XcodeConsole *console = [[XcodeConsole alloc] initWithConsole:[self findConsoleAndActivate]];
    for (id xcode3Project in xcode3Projects) {
        NSString *mavenProjectRootDirectory = [SAPXcodeMavenPlugin getMavenProjectRootDirectory:xcode3Project];
        NSString *pom = [SAPXcodeMavenPlugin getPomFilePath:xcode3Project];
        if (![NSFileManager.defaultManager fileExistsAtPath:pom]) {
            [console appendText:[NSString stringWithFormat:@"pom.xml not found at %@\n", pom] color:NSColor.redColor];
        } else {
            NSTask *task = [self initializeTaskWithPath:mavenProjectRootDirectory configuration:configuration];
            RunOperation *operation = [[RunOperation alloc] initWithTask:task];
            operation.xcodeConsole = console;
            [self.initializeQueue addOperation:operation];
        }
    }
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

-(void)updateVersionInAllPoms:(MyMenuItem *) menuItem {
    XcodeConsole *console = [[XcodeConsole alloc] initWithConsole:[self findConsoleAndActivate]];
    [self runUpdateVersionInPomForProjects:menuItem.xcode3Projects withConsole:console];
}

- (void)updateVersionInPom:(MyMenuItem *) menuItem {
    XcodeConsole *console = [[XcodeConsole alloc] initWithConsole:[self findConsoleAndActivate]];
    [self runUpdateVersionInPomForProject:menuItem.xcode3Projects[0] withConsole:console];
}

-(void)runUpdateVersionInPomForProjects:(NSArray *)xcode3Projects withConsole:(XcodeConsole *)console {

    for(id xcode3Project in xcode3Projects) {
        [self runUpdateVersionInPomForProject:xcode3Project withConsole:console];
    }
}

- (void)runUpdateVersionInPomForProject:(id) xcode3Project withConsole:(XcodeConsole*)console {
    
    [FileLogger log: [NSString stringWithFormat:@"Update version in Pom triggered for project: %@", [xcode3Project description]]];
    
    NSString *mavenProjectPath = [SAPXcodeMavenPlugin getMavenProjectRootDirectory:xcode3Project];
    
    if (![NSFileManager.defaultManager fileExistsAtPath:[mavenProjectPath stringByAppendingPathComponent:@"pom.xml"]]) {
        [console appendText:[NSString stringWithFormat:@"pom.xml not found at %@\n", mavenProjectPath] color:NSColor.redColor];
        return;
    }
        
    NSTask *task = [self updateVersionTaskWithPath:mavenProjectPath];
    RunOperation *operation = [[RunOperation alloc] initWithTask:task];
    operation.xcodeConsole = console;
    [self.initializeQueue addOperation:operation];
    
}

- (NSTask *)updateVersionTaskWithPath:(NSString *)path {
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/mvn";
    task.currentDirectoryPath = path;
    
    NSMutableArray *arguments = [NSMutableArray arrayWithCapacity:8];
    
    NSString *pluginGAV = @"com.sap.prd.mobile.ios.mios:xcode-maven-plugin:1.6.1-SNAPSHOT";
    
    [arguments addObject: [[NSString alloc] initWithFormat:@"%@:%@", pluginGAV, @"check-prerequisites"]];
    [arguments addObject: [[NSString alloc] initWithFormat:@"%@:%@", pluginGAV, @"change-artifact-id"]];
    [arguments addObject: [[NSString alloc] initWithFormat:@"%@:%@", pluginGAV, @"set-default-configuration"]];
    [arguments addObject: [[NSString alloc] initWithFormat:@"%@:%@", pluginGAV, @"xcode-project-validate"]];
    [arguments addObject: [[NSString alloc] initWithFormat:@"%@:%@", pluginGAV, @"prepare-xcode-build"]];
    [arguments addObject: [[NSString alloc] initWithFormat:@"%@:%@", pluginGAV, @"copy-sources"]];
    [arguments addObject: [[NSString alloc] initWithFormat:@"%@:%@", pluginGAV, @"save-build-settings"]];
    [arguments addObject: [[NSString alloc] initWithFormat:@"%@:%@", pluginGAV, @"update-version-in-pom"]];
    
    task.arguments = arguments;
    
    return task;
}

- (NSTask *)initializeTaskWithPath:(NSString *)path configuration:(InitializeConfiguration *)configuration {
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/mvn";
    task.currentDirectoryPath = path;
    NSMutableArray *args = [@[@"-B"] mutableCopy];
    if (configuration) {
        if (configuration.debug) {
            [args addObject:@"-X"];
        }
        if (configuration.forceUpdate) {
            [args addObject:@"-U"];
        }
        if (configuration.clean) {
            [args addObject:@"clean"];
        }
    }
    [args addObject:@"initialize"];
    task.arguments = args;
    return task;
}

- (NSTextView *)findConsoleAndActivate {
    Class consoleTextViewClass = objc_getClass("IDEConsoleTextView");
    NSTextView *console = (NSTextView *)[self findView:consoleTextViewClass inView:NSApplication.sharedApplication.mainWindow.contentView];
    
    if (console) {
        NSWindow *window = NSApplication.sharedApplication.keyWindow;
        if ([window isKindOfClass:objc_getClass("IDEWorkspaceWindow")]) {
            if ([window.windowController isKindOfClass:NSClassFromString(@"IDEWorkspaceWindowController")]) {
                id editorArea = [window.windowController valueForKey:@"editorArea"];
                [editorArea performSelector:@selector(activateConsole:) withObject:self];
            }
        }
    }
    
    return console;
}

- (NSView *)findView:(Class)consoleClass inView:(NSView *)view {
    if ([view isKindOfClass:consoleClass]) {
        return view;
    }
    
    for (NSView *v in view.subviews) {
        NSView *result = [self findView:consoleClass inView:v];
        if (result) {
            return result;
        }
    }
    return nil;
}

@end
