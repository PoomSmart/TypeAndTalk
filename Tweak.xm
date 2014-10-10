#import <substrate.h>
#import <objc/runtime.h>
#import <Preferences/Preferences.h>
#import <Preferences/PSSpecifier.h>

extern NSString *const PSDefaultsKey;
extern NSString *const PSKeyNameKey;
extern NSString *const PSTableCellKey;
extern NSString *const PSDefaultValueKey;
NSString *const tatKey = @"KeyboardTypeAndTalk";
NSString *const keyboardPrefPath = [NSHomeDirectory() stringByAppendingPathComponent:@"/Library/Preferences/com.apple.keyboard.plist"];

@interface UIKeyboardPreferencesController : NSObject
+ (UIKeyboardPreferencesController *)sharedPreferencesController;
- (BOOL)boolForKey:(NSString *)key;
- (void)synchronizePreferences;
@end

%group tat

%hook UIDictationController

+ (BOOL)usingTypeAndTalk
{
	NSDictionary *prefDict = [NSDictionary dictionaryWithContentsOfFile:keyboardPrefPath] ?: [NSDictionary dictionary];
	return [prefDict[tatKey] boolValue];
}

%end

%end

%group Pref

static char tatSpecifierKey;

@interface KeyboardController : UIViewController
@property (retain, nonatomic, getter=_tat_specifier, setter=_set_tat_specifier:) PSSpecifier *tatSpecifier;
@end

%hook KeyboardController

%new(v@:@)
- (void)_set_tat_specifier:(id)object
{
    objc_setAssociatedObject(self, &tatSpecifierKey, object, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

%new(@@:)
- (id)_tat_specifier
{
    return objc_getAssociatedObject(self, &tatSpecifierKey);
}

%new
- (id)tat_getValue:(PSSpecifier *)specifier
{
	NSDictionary *prefDict = [NSDictionary dictionaryWithContentsOfFile:keyboardPrefPath] ?: [NSDictionary dictionary];
	id value = prefDict[tatKey];
	return value != nil ? value : @NO;
}

%new
- (void)tat_setValue:(id)value specifier:(PSSpecifier *)specifier
{
	NSMutableDictionary *prefDict = [[NSDictionary dictionaryWithContentsOfFile:keyboardPrefPath] mutableCopy] ?: [NSMutableDictionary dictionary];
	[prefDict setObject:value forKey:tatKey];
	[prefDict writeToFile:keyboardPrefPath atomically:YES];
}

- (NSMutableArray *)specifiers
{
	if (MSHookIvar<NSMutableArray *>(self, "_specifiers") != nil)
		return %orig();
	NSMutableArray *specifiers = %orig();
	NSUInteger insertionIndex = NSNotFound;
	for (PSSpecifier *spec in specifiers) {
		if ([[spec propertyForKey:@"label"] isEqualToString:@"PERIOD_SHORTCUT"])
			insertionIndex = [specifiers indexOfObject:spec];
	}
	if (insertionIndex == NSNotFound)
		return specifiers;
	insertionIndex++;
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

%ctor
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	BOOL isPrefApp = [[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.Preferences"];
	if (isPrefApp) {
		dlopen("/System/Library/PreferenceBundles/KeyboardSettings.bundle/KeyboardSettings", RTLD_LAZY);
		%init(Pref);
	} else {
		%init(tat);
	}
	[pool drain];
}
