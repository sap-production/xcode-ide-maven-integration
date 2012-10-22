# Xcode IDE Maven Plugin 

## Overview

This plugin shows how to integrate into Xcode, run a command line utility, get information about the current workspace and scheme. It is still experimental, but works fine with Xcode 4.5.
It can also serve as a good starting point for your own plugins.

## Installation

Simply build the Xcode project and restart Xcode. The plugin will automatically be installed in `~/Library/Application Support/Developer/Shared/Xcode/Plug-ins`. To uninstall, just remove the plugin from there (and restart Xcode).

## Make your own plugin

If you intend to create your own plugin, here is a quickstart to save you some hours of trial and error.

1. Create a new `Bundle` project for OS X.
2. Create a new class, e.g. `MyPlugin`.
3. Add the following entries to your `Info.plist`:

        <key>NSPrincipalClass</key>
        <string>MyPlugin</string>
        <key>XC4Compatible</key>
        <true/>
        <key>XCGCReady</key>
        <true/>
        <key>XCPluginHasUI</key>
        <false/>

4. Add/set the following Build Settings to/in your target:

        DEPLOYMENT_LOCATION = YES
        DEPLOYMENT_POSTPROCESSING = YES
        DSTROOT = $(HOME)
        INSTALL_PATH = /Library/Application Support/Developer/Shared/Xcode/Plug-ins
        LD_RUNPATH_SEARCH_PATHS = /Developer
        WRAPPER_EXTENSION = xcplugin
        CLANG_ENABLE_OBJC_ARC = NO
        GCC_ENABLE_OBJC_GC = supported

5. Add the following method with your initialization code to your `MyPlugin` class:

        + (void)pluginDidLoad:(NSBundle *)bundle {
            // ...
        }

See the source code for further concepts:
* How to access/modify the main menu.
* Get the current workspace.
* Get the current scheme.
* ...

## Disclaimer

This plugin is still experimental, so use it at your own risk.

## Credits

The following links was helpful in order to develop this plugin.
* Your best friend: [https://github.com/probablycorey/xcode-class-dump](https://github.com/probablycorey/xcode-class-dump)
* [http://code.google.com/p/google-toolbox-for-mac/wiki/GTMXcodePlugin](http://code.google.com/p/google-toolbox-for-mac/wiki/GTMXcodePlugin)
* [https://github.com/omz/MiniXcode](https://github.com/omz/MiniXcode)
* [https://github.com/0xced/CLITool-InfoPlist](https://github.com/0xced/CLITool-InfoPlist)

