#import <dlfcn.h>
#import <Preferences/Preferences.h>

NSString *const tatKey = @"KeyboardTypeAndTalk";
NSString *const keyboardPrefPath = @"/var/mobile/Library/Preferences/com.apple.keyboard.plist";

static BOOL isEnabled() {
    NSDictionary *prefDict = [NSDictionary dictionaryWithContentsOfFile:keyboardPrefPath] ?: [NSDictionary dictionary];
    return [prefDict[tatKey] boolValue];
}

%group tat

%hook UIDictationController

+ (int)viewMode {
    return isEnabled() ? 5 : %orig;
}

+ (BOOL)usingTypeAndTalk {
    return isEnabled();
}

%end

%end

%group Pref

@interface KeyboardController : UIViewController
@property (retain, nonatomic, getter=_tat_specifier, setter=_set_tat_specifier:) PSSpecifier *tatSpecifier;
@end

%hook KeyboardController

%property (retain, nonatomic, getter=_tat_specifier, setter=_set_tat_specifier:) PSSpecifier *tatSpecifier;

%new
- (id)tat_getValue:(PSSpecifier *)specifier {
    return @(isEnabled());
}

%new
- (void)tat_setValue:(id)value specifier:(PSSpecifier *)specifier {
    NSMutableDictionary *prefDict = [[NSDictionary dictionaryWithContentsOfFile:keyboardPrefPath] mutableCopy] ?: [NSMutableDictionary dictionary];
    [prefDict setObject:value forKey:tatKey];
    [prefDict writeToFile:keyboardPrefPath atomically:YES];
}

- (NSMutableArray *)specifiers {
    if ([self valueForKey:@"_specifiers"])
        return %orig;
    NSMutableArray *specifiers = %orig;
    NSUInteger insertionIndex = NSNotFound;
    for (PSSpecifier *spec in specifiers) {
        if ([[spec propertyForKey:@"label"] isEqualToString:@"PERIOD_SHORTCUT"]) {
            insertionIndex = [specifiers indexOfObject:spec];
            break;
        }
    }
    if (insertionIndex == NSNotFound)
        return specifiers;
    ++insertionIndex;
    PSSpecifier *tatSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Type & Talk" target:self set:@selector(tat_setValue:specifier:) get:@selector(tat_getValue:) detail:nil cell:[PSTableCell cellTypeFromString:@"PSSwitchCell"] edit:nil];
    [tatSpecifier setProperty:@"com.apple.Preferences" forKey:PSDefaultsKey];
    [tatSpecifier setProperty:tatKey forKey:PSKeyNameKey];
    [tatSpecifier setProperty:@NO forKey:PSDefaultValueKey];
    [specifiers insertObject:tatSpecifier atIndex:insertionIndex];
    self.tatSpecifier = tatSpecifier;
    return specifiers;
}

%end

%end

%ctor {
    BOOL isPrefApp = [[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.Preferences"];
    if (isPrefApp) {
        dlopen("/System/Library/PreferenceBundles/KeyboardSettings.bundle/KeyboardSettings", RTLD_LAZY);
        %init(Pref);
    } else {
        %init(tat);
    }
}
