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

#import "InitializeWindowController.h"

@interface InitializeWindowController ()

@property (retain) IBOutlet NSButton *cleanCheckBox;
@property (retain) IBOutlet NSButton *debugCheckBox;
@property (retain) IBOutlet NSButton *forceUpdateCheckBox;

@end

@implementation InitializeWindowController

- (void)windowDidLoad {
    [super windowDidLoad];
    NSButton *closeButton = [self.window standardWindowButton:NSWindowCloseButton];
    closeButton.target = self;
    closeButton.action = @selector(closeButtonClicked);
}

- (void)closeButtonClicked {
    [self.window close];
    if (self.cancel) {
        self.cancel();
    }
}

- (IBAction)run:(id)sender {
    if (self.run) {
        InitializeConfiguration *configuration = [[InitializeConfiguration alloc] init];
        configuration.clean = self.cleanCheckBox.state == NSOnState;
        configuration.debug = self.debugCheckBox.state == NSOnState;
        configuration.forceUpdate = self.forceUpdateCheckBox.state == NSOnState;
        self.run(configuration);
    }
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
    if (item == nil) {
        return self.xcode3Projects.count;
    }
    return 1;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
    id project = self.xcode3Projects[index];
    if (item == nil) {
        return project;
    }
    return [[project valueForKey:@"filePath"] valueForKey:@"pathString"];
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
    if ([self.xcode3Projects containsObject:item]) {
        return [item name];
    }
    return item;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
    return [self.xcode3Projects containsObject:item];
}

@end
