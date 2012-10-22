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

#import "XcodeConsole.h"

@interface XcodeConsole ()

@property (retain) NSTextView *console;

@end


@implementation XcodeConsole

- (id)initWithConsole:(NSTextView *)console {
    self = [super init];
    if (self) {
        self.console = console;
    }
    return self;
}

- (void)appendText:(NSString *)text {
    [self appendText:text color:NSColor.blackColor];
}

- (void)appendText:(NSString *)text color:(NSColor *)color {
    if (text == nil) {
        return;
    }

    NSMutableDictionary *attributes = [@{NSForegroundColorAttributeName: color } mutableCopy];
    NSFont *font = [NSFont fontWithName:@"Menlo Regular" size:11];
    if (font) {
        attributes[NSFontAttributeName] = font;
    }
    NSAttributedString *as = [[NSAttributedString alloc] initWithString:text attributes:attributes];
    NSRange theEnd = NSMakeRange(self.console.string.length, 0);
    theEnd.location += as.string.length;
    if (NSMaxY(self.console.visibleRect) == NSMaxY(self.console.bounds)) {
        [self.console.textStorage appendAttributedString:as];
        [self.console scrollRangeToVisible:theEnd];
    } else {
        [self.console.textStorage appendAttributedString:as];
    }
}

@end
