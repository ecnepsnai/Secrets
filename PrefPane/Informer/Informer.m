//
//  Informer.m
//  Informer
//
//  Created by Nicholas Jitkoff on 3/4/08.

#import <Foundation/Foundation.h>
#import "dyld-interposing.h"
#import "/usr/include/objc/runtime.h"

void NoteCFPreferencesInfo(NSString * key, NSString * infoKey, CFPropertyListRef value, CFStringRef applicationID, CFStringRef userName, CFStringRef hostName) {
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  
  
  if ([key rangeOfString:@"/"].location != NSNotFound)
    key = [key stringByReplacingOccurrencesOfString:@"/" withString:@":"];
  
  BOOL isNS = [key hasPrefix:@"NS"] || [key hasPrefix:@"WebKit"] || [key hasPrefix:@"_NS"] || [key hasPrefix:@"__NS"] ||  [key hasPrefix:@"Apple"] ||  [key hasPrefix:@"CF"] || [key hasPrefix:@"com.apple"] ||  [key hasPrefix:@"AB"] ||  [key hasPrefix:@"_CF"];;

  NSString *identifier = [[NSBundle mainBundle] bundleIdentifier];
  
  NSString *basepath = [@"~/Library/Caches/Informer" stringByStandardizingPath];
  if (isNS) key = [@"Apple/" stringByAppendingString:key];

  // Accessing own domain
  if (CFEqual(applicationID, kCFPreferencesCurrentApplication)) {
    applicationID = (CFStringRef)[basepath stringByAppendingFormat:@"/%@./%@",identifier, key];
    
  // Accessing global domain
  } else if (CFEqual(applicationID, kCFPreferencesAnyApplication)) {
    applicationID = (CFStringRef)[basepath stringByAppendingFormat:@"/%@./%@/%@", applicationID, key, identifier];
    
  // Accessing another domain
  } else {
    applicationID = (CFStringRef)[basepath stringByAppendingFormat:@"/%@./%@./%@/%@",identifier, applicationID, key, identifier];
  }

  CFPreferencesSetValue((CFStringRef)infoKey, value, (CFStringRef)applicationID, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
  CFPreferencesAppSynchronize((CFStringRef)applicationID);
  [pool release];
}
  
@implementation NSUserDefaults (Informer)

- (id)secretObjectForKey:(NSString *)defaultName{
  id value = [self secretObjectForKey:defaultName];
  NoteCFPreferencesInfo(defaultName, @"ndvalue", value, kCFPreferencesCurrentApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
  return value;
}

- (NSArray *)secretArrayForKey:(NSString *)defaultName {
  NoteCFPreferencesInfo(defaultName, @"type", @"array", kCFPreferencesCurrentApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
  return [self secretArrayForKey:defaultName];
}

- (NSDictionary *)secretDictionaryForKey:(NSString *)defaultName {
  NoteCFPreferencesInfo(defaultName, @"type", @"dictionary", kCFPreferencesCurrentApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
  return [self secretDictionaryForKey:defaultName];
}

- (NSData *)secretDataForKey:(NSString *)defaultName {
  NoteCFPreferencesInfo(defaultName, @"type", @"data", kCFPreferencesCurrentApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
  return [self secretDataForKey:defaultName];
}

- (NSArray *)secretStringArrayForKey:(NSString *)defaultName {
  NoteCFPreferencesInfo(defaultName, @"type", @"stringArray", kCFPreferencesCurrentApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
  return [self secretStringArrayForKey:defaultName];
}

- (NSInteger)secretIntegerForKey:(NSString *)defaultName {
  NoteCFPreferencesInfo(defaultName, @"type", @"integer", kCFPreferencesCurrentApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
  return [self secretIntegerForKey:defaultName];
}

- (float)secretFloatForKey:(NSString *)defaultName {
  NoteCFPreferencesInfo(defaultName, @"type", @"float", kCFPreferencesCurrentApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
  return [self secretFloatForKey:defaultName];
}

- (double)secretDoubleForKey:(NSString *)defaultName {
  NoteCFPreferencesInfo(defaultName, @"type", @"double", kCFPreferencesCurrentApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
  return [self secretDoubleForKey:defaultName];
}

- (NSString *)secretStringForKey:(NSString *)defaultName {
  NoteCFPreferencesInfo(defaultName, @"type", @"string", kCFPreferencesCurrentApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
  return [self secretStringForKey:defaultName];
}

- (BOOL)secretBoolForKey:(NSString*)defaultName {
  NoteCFPreferencesInfo(defaultName, @"type", @"bool", kCFPreferencesCurrentApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
  return [self secretBoolForKey:defaultName];
}

- (void)secretRegisterDefaults:(NSDictionary *)registrationDictionary {
  for (NSString *key in registrationDictionary) {
    id value = [registrationDictionary objectForKey:key];
    NoteCFPreferencesInfo(key, @"registered", value, kCFPreferencesCurrentApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);    
  }
  [self secretRegisterDefaults:registrationDictionary];
}
@end

CFDictionaryRef MyCFPreferencesCopyMultiple(CFArrayRef keysToFetch, CFStringRef applicationID, CFStringRef userName, CFStringRef hostName){
  printf("multiple");
  return CFPreferencesCopyMultiple( keysToFetch,  applicationID,  userName,  hostName);
}

void MyCFPreferencesAddSuitePreferencesToApp(CFStringRef applicationID, CFStringRef suiteID) {
  NSLog(@"addsuite %@", applicationID);
}

Boolean MyCFPreferencesGetAppBooleanValue(CFStringRef key, CFStringRef applicationID, Boolean *keyExistsAndHasValidFormat) {
  NoteCFPreferencesInfo((NSString *)key, @"type", @"bool", applicationID, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
  return CFPreferencesGetAppBooleanValue( key,  applicationID,  keyExistsAndHasValidFormat);
}

CFIndex MyCFPreferencesGetAppIntegerValue(CFStringRef key, CFStringRef applicationID, Boolean *keyExistsAndHasValidFormat) {
  NoteCFPreferencesInfo((NSString *)key, @"type", @"integer", applicationID, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
  return CFPreferencesGetAppIntegerValue( key,  applicationID,  keyExistsAndHasValidFormat);
}

DYLD_INTERPOSE(MyCFPreferencesGetAppIntegerValue, CFPreferencesGetAppIntegerValue)


CFPropertyListRef MyCFPreferencesCopyValue (CFStringRef key,
                                            CFStringRef applicationID,
                                            CFStringRef userName,
                                            CFStringRef hostName) {
  
  CFPropertyListRef value = CFPreferencesCopyValue(key, applicationID, userName, hostName);
  NoteCFPreferencesInfo((NSString *)key, @"value", value ? value : @"(null)", applicationID, userName, hostName);
  NoteCFPreferencesInfo((NSString *)key, @"key", key, applicationID, userName, hostName);
  return value;
}

DYLD_INTERPOSE(MyCFPreferencesCopyValue, CFPreferencesCopyValue)


__attribute__ ((constructor))
void MyConstructor(void) {
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  
  NSLog(@"Informer loaded");
  if ([[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.blacktree.Quicksilver"]) return;
  
  Class D = [NSUserDefaults class];
  method_exchangeImplementations(class_getInstanceMethod(D, @selector(secretRegisterDefaults:)),
                                 class_getInstanceMethod(D, @selector(registerDefaults:)));
  method_exchangeImplementations(class_getInstanceMethod(D, @selector(secretObjectForKey:)),
                                 class_getInstanceMethod(D, @selector(objectForKey:)));
  method_exchangeImplementations(class_getInstanceMethod(D, @selector(secretStringForKey:)),
                                 class_getInstanceMethod(D, @selector(stringForKey:)));
  method_exchangeImplementations(class_getInstanceMethod(D, @selector(secretBoolForKey:)),
                                 class_getInstanceMethod(D, @selector(boolForKey:)));
  method_exchangeImplementations(class_getInstanceMethod(D, @selector(secretArrayForKey:)),
                                 class_getInstanceMethod(D, @selector(arrayForKey:)));
  method_exchangeImplementations(class_getInstanceMethod(D, @selector(secretDictionaryForKey:)),
                                 class_getInstanceMethod(D, @selector(dictionaryForKey:)));
  method_exchangeImplementations(class_getInstanceMethod(D, @selector(secretIntegerForKey:)),
                                 class_getInstanceMethod(D, @selector(integerForKey:)));
  method_exchangeImplementations(class_getInstanceMethod(D, @selector(secretDataForKey:)),
                                 class_getInstanceMethod(D, @selector(dataForKey:)));
  method_exchangeImplementations(class_getInstanceMethod(D, @selector(secretFloatForKey:)),
                                 class_getInstanceMethod(D, @selector(floatForKey:)));
  method_exchangeImplementations(class_getInstanceMethod(D, @selector(secretDoubleForKey:)),
                                 class_getInstanceMethod(D, @selector(doubleForKey:)));
  method_exchangeImplementations(class_getInstanceMethod(D, @selector(secretStringArrayForKey:)),
                                 class_getInstanceMethod(D, @selector(stringArrayForKey:)));  
  
  [pool release];
}


