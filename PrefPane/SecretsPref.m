//
//  SecretsPref.m
//  Secrets
//
//  Created by Nicholas Jitkoff on 9/9/06.


#import "SecretsPref.h"
#import "NSSortDescriptor+BLTRExtensions.h"
#import "NSImage_BLTRExtensions.h"

#define foreach(x, y) id x; NSEnumerator *rwEnum = [y objectEnumerator]; while(x = [rwEnum nextObject])
#define kSecretsLiveURL [NSURL URLWithString:@"http://secrets.blacktree.com/plist"]
#define kSecretsSafeURL [NSURL URLWithString:@"http://secrets.blacktree.com/plist"]
#define kSecretsStableURL [NSURL URLWithString:@"http://secrets.blacktree.com/plist"]
#define kSecretsHelpURL [NSURL URLWithString:@"http://code.google.com/p/blacktree-secrets/wiki/Help"]
#define kSecretsEditFormatString @"http://secrets.blacktree.com/edit?id=%@"
#define kSecretsSiteURL [NSURL URLWithString:@"http://secrets.blacktree.com/"]


@interface SecretsPref ()
- (NSData *)downloadData;
- (id)getUserDefaultsValueForKey:(NSString *)path bundle:(NSString *)bundle user:(CFStringRef)user host:(CFStringRef)host asKeyPath:(BOOL)asKeyPath;

- (id)getUserDefaultsValueForInfo:(NSDictionary *)thisInfo;
- (NSArray *)secretsArray;
- (void)updateEntries;
@end

@implementation SecretsPref
@synthesize fetchConnection, fetchData, entries, categories, currentEntry, showInfo, bundles, searchPredicate;


- (IBAction)clickedEntry:(id)sender { 
  if ([sender clickedColumn] < 0) return;
  NSTableColumn *column = [[sender tableColumns] objectAtIndex:[sender clickedColumn]];
  int row = [sender clickedRow];
  if (row < 0) return;
  if (row > [[entriesController arrangedObjects] count]) return;
  
  
  
  if ([[column identifier] isEqualToString:@"value"]) {
    id thisInfo = [[entriesController arrangedObjects] objectAtIndex: row]; 
    
    NSString *type = [thisInfo objectForKey:@"datatype"];
    if ([type isEqualToString:@"path"]) {
      NSOpenPanel *panel = [NSOpenPanel openPanel];
      NSString *directory = [self tableView:entriesTable objectValueForTableColumn:column row:row];
      [panel setDirectory:directory];
      [panel setCanChooseDirectories:YES];
      [panel setResolvesAliases:YES];
      NSInteger integer = [panel runModalForDirectory:[directory stringByDeletingLastPathComponent] file:[directory lastPathComponent]];
      if (integer) {
        NSString *path = [[panel filenames] lastObject];
        [self tableView:entriesTable setObjectValue:path forTableColumn:column row:row];
      }
      return;
    }
    
    
    if ([[sender preparedCellAtColumn:[sender clickedColumn] row:row] isKindOfClass:[NSTextFieldCell class]]) {
      [sender editColumn:[sender clickedColumn] row:[sender clickedRow] withEvent:[NSApp currentEvent] select:YES];
    }
    return;
  } 
}

- (IBAction)openEntry:(id)sender {
  int row = [entriesTable selectedRow];
  id thisInfo = [[entriesController arrangedObjects] objectAtIndex: row]; 	
  NSString *idNumber = [thisInfo objectForKey:@"id"];
  NSString *urlString = [NSString stringWithFormat:kSecretsEditFormatString, idNumber];
  NSURL *url = [NSURL URLWithString:urlString];
  [[NSWorkspace sharedWorkspace] openURL:url];
  
}

-(OSStatus)quitApplicationWithBundleID:(NSString *)bundleID {
  OSStatus err;
  AppleEvent event, reply;
  
  const char *bundleIDString = [bundleID UTF8String];
  
  err = AEBuildAppleEvent(kCoreEventClass, kAEQuitApplication,
                          typeApplicationBundleID, 
                          bundleIDString, strlen(bundleIDString),
                          kAutoGenerateReturnID, kAnyTransactionID,
                          &event, NULL, "");
  
  if (err == noErr) {
    err = AESendMessage(&event, &reply, kAENoReply, kAEDefaultTimeout);
    (void)AEDisposeDesc(&event);
  }
  return err;
}

- (IBAction)quitEntry:(id)sender {
  int row = [entriesTable selectedRow];
  id thisInfo = [[entriesController arrangedObjects] objectAtIndex: row]; 	
  NSDictionary *app = [thisInfo objectForKey:@"container"];
  
  [self quitApplicationWithBundleID:[app valueForKey:@"NSApplicationBundleIdentifier"]];
  
  // make it undirty, even if it still is
  [app setValue:nil forKey:@"dirty"];
  
}

- (void) willSelect {
  previousLaunchDate = [[NSUserDefaults standardUserDefaults] objectForKey:@"SecretsLastDownloadDate"];
  // Show changes from the last week
  previousLaunchDate = [[NSDate dateWithTimeIntervalSinceNow:-7*24*60*60] earlierDate:previousLaunchDate];
  [previousLaunchDate retain];
  [self loadInfo:nil];
}

- (void)warnAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
  [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"SecretsWarningShown"];
  [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)didSelect {
  [[[self mainView] window] setContentBorderThickness:32 forEdge:NSMinYEdge];
  
  if (![[NSUserDefaults standardUserDefaults] boolForKey:@"SecretsWarningShown"]) {
    
    NSAlert *updateAlert = [NSAlert alertWithMessageText:@"Welcome to Secrets"
                                           defaultButton:@"I've Been Warned" 
                                         alternateButton:nil
                                             otherButton:nil
                               informativeTextWithFormat:@"Secrets is BETA software and many of these values can harm your system if used improperly. Use it at your own risk."];
    
    [updateAlert beginSheetModalForWindow:[[self mainView] window]
                            modalDelegate:self
                           didEndSelector:@selector(warnAlertDidEnd:returnCode:contextInfo:)
                              contextInfo:NULL];
  }  
  
  
  NSDate *lastDownloadDate = [[NSUserDefaults standardUserDefaults] objectForKey:@"SecretsLastDownloadDate"];
  float interval = [[NSUserDefaults standardUserDefaults] floatForKey:@"SecretsDownloadInterval"];
  if (interval < 60) interval = 7 * 24 * 60 * 60;
  if (interval < 7 * 24 * 60 * 60) interval = 60 * 60; // Don't allow auto-checking more than once an hour
  
  if (![self secretsArray]
      || !lastDownloadDate 
      || -[lastDownloadDate timeIntervalSinceNow] > interval) {
    [self reloadInfo:nil];
  }
  [[[self mainView] window] performSelector:@selector(makeFirstResponder:) withObject:searchField afterDelay:0.0];
}

- (void)willUnselect {
  [[[self mainView] window] setContentBorderThickness:0 forEdge:NSMinYEdge];
}

- (void)appLaunched:(NSNotification *)notif {
  NSString *bundle = [[notif userInfo] objectForKey:@"NSApplicationBundleIdentifier"];
  
  [[bundles objectForKey:bundle] setValue:nil forKey:@"dirty"];
  [[bundles objectForKey:bundle] setValue:[NSNumber numberWithBool:YES] forKey:@"running"];
  [[bundles objectForKey:bundle] setValuesForKeysWithDictionary:[notif userInfo]];
}


- (void)appTerminated:(NSNotification *)notif {
  NSString *bundle = [[notif userInfo] objectForKey:@"NSApplicationBundleIdentifier"];
  [[bundles objectForKey:bundle] setValue:nil forKey:@"dirty"];
  [[bundles objectForKey:bundle] setValue:[NSNumber numberWithBool:NO] forKey:@"running"];
}



- (void)awakeFromNib {
  
  [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                         selector:@selector(appLaunched:)
                                                             name:NSWorkspaceDidLaunchApplicationNotification
                                                           object:nil];
  
  [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                         selector:@selector(appTerminated:)
                                                             name:NSWorkspaceDidTerminateApplicationNotification
                                                           object:nil];
  
  //	[categoriesController addObserver:self
  //                         forKeyPath:@"selectedObjects"
  //                            options:0
  //                            context:nil];
  
  [entriesController setSortDescriptors:[NSArray arrayWithObjects:
                                         
                                         [NSSortDescriptor descriptorWithKey:@"display_bundle"
                                                                   ascending:YES],
                                         
                                         [NSSortDescriptor descriptorWithKey:@"group"
                                                                   ascending:YES],
                                         [NSSortDescriptor descriptorWithKey:@"title"
                                                                   ascending:YES
                                                                    selector:@selector(caseInsensitiveCompare:)],
                                         
                                         nil]];
  
  
  [categoriesController setSortDescriptors:[NSArray arrayWithObjects:
                                            [NSSortDescriptor descriptorWithKey:@"rank"
                                                                      ascending:NO],
                                            [NSSortDescriptor descriptorWithKey:@"text"
                                                                      ascending:YES
                                                                       selector:@selector(caseInsensitiveCompare:)],
                                            nil]];
  
  
  [entriesTable setAction:@selector(clickedEntry:)];
  [entriesTable setTarget:self];
  [entriesTable setIntercellSpacing:NSMakeSize(6, 8)];
  [categoriesTable setIntercellSpacing:NSMakeSize(0, 1)];
  NSTableColumn *iconColumn = [entriesTable tableColumnWithIdentifier:@"icon"];
  [[iconColumn dataCell] setImageAlignment:NSImageAlignTopRight];
  
  
  
  [[NSNotificationCenter defaultCenter]
   addObserver:self
   selector:@selector(columnResized)
   name:NSTableViewColumnDidResizeNotification
   object:entriesTable];
}

- (NSArray *)secretsArray {
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString *path = [@"~/Library/Caches/Secrets.plist" stringByStandardizingPath];
  
  if (![fm fileExistsAtPath:path]) {
    NSLog(@"No cache, using internal secrets");
    path = [[NSBundle bundleForClass:[self class]] pathForResource:@"Secrets" ofType:@"plist"];
  }
  NSData *data = [NSData dataWithContentsOfFile:path];
  
  NSArray *array = [NSPropertyListSerialization 
                    propertyListFromData:data
                    mutabilityOption:NSPropertyListMutableContainers
                    format:nil errorDescription:nil];
  
  return array;
}

- (NSData *)downloadData {
  
  [[NSUserDefaults standardUserDefaults] setValue:[NSDate date] forKey:@"SecretsLastDownloadDate"];
  [[NSUserDefaults standardUserDefaults] synchronize];
  
  downloading = YES;
  [progressField setStringValue:@"Loading Data"];
  [progressField display];
  
  
  
  NSString *surl = [self getUserDefaultsValueForKey:@"secretsURL"
                                             bundle:@"com.blacktree.secrets"
                                               user:kCFPreferencesCurrentUser 
                                               host:kCFPreferencesAnyHost 
                                          asKeyPath:NO];
  
  NSURL *url = nil;
  if ([surl isEqualToString:@"SAFE_SERVER"]) {
    url = kSecretsSafeURL;
  } else if ([surl isEqualToString:@"STABLE_SERVER"]) {
    url = kSecretsStableURL;
  } else if ([surl isEqualToString:@"LIVE_SERVER"]) {
    url = kSecretsLiveURL;
  } else if (!surl) {
    url = kSecretsStableURL;
  } else {
    url = [NSURL URLWithString:surl];
  }
  NSLog(@"Secrets: Loading secrets from %@", url);
  
  NSURLRequest *request = [NSURLRequest requestWithURL:url
                                           cachePolicy:NSURLRequestReloadIgnoringCacheData
                                       timeoutInterval:10.0];
  
  if (!self.fetchConnection) {
    self.fetchConnection = [NSURLConnection connectionWithRequest:request delegate:self];
    self.fetchData = [NSMutableData data];
    [progressIndicator startAnimation:nil];
    return nil;
  }
  NSLog(@"Secrets: Connection already in progress");
  return nil;
}

- (IBAction)reloadInfo:(id)sender {
  [self downloadData];
}

- (IBAction)loadInfo:(id)sender {
  NSMutableArray *array = [NSMutableArray array]; ;
  [array addObjectsFromArray:[self secretsArray]];
  
  NSString *extensionsPath=
  [@"~/Library/Application Support/Secrets/" stringByStandardizingPath];
  
  NSFileManager *fm = [NSFileManager defaultManager];
  
  NSArray *files = [fm directoryContentsAtPath:extensionsPath];
  files = [files pathsMatchingExtensions:[NSArray arrayWithObject:@"secrets"]];
  for(NSString *file in files) {
    NSData *data = [NSData dataWithContentsOfFile:[extensionsPath stringByAppendingPathComponent:file]];
    NSArray *fileArray = [NSPropertyListSerialization propertyListFromData:data mutabilityOption:NSPropertyListMutableContainers
                                                                    format:nil errorDescription:nil];
    
    for (NSDictionary *entry in fileArray) {
      NSString *display_bundle = [entry objectForKey:@"display_bundle"];
      if (!display_bundle) {
        display_bundle = [entry objectForKey:@"bundle"];
        if (display_bundle) [entry setValue:display_bundle forKey:@"display_bundle"];
      }
    }
    [array addObjectsFromArray:fileArray];
  }
  
  self.entries = array;
  if (!self.bundles) self.bundles = [NSMutableDictionary dictionary];
  
  NSString *imagePath = [[NSBundle bundleForClass:[self class]] pathForImageResource:@"Application"];
  NSImage *image = [[[NSImage alloc] initWithContentsOfFile:imagePath] autorelease];
  
  NSMutableDictionary *topSecrets = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                     @"Top Secrets", @"text",
                                     [NSNumber numberWithInt:3], @"rank", 
                                     image , @"image", 
                                     [NSNumber numberWithBool:YES], @"globalSearch",
                                     [NSNumber numberWithBool:YES], @"bold",
                                     [NSNumber numberWithBool:YES], @"hideGroups",
                                     [NSPredicate predicateWithFormat:@"top_secret == TRUE"],  @"predicate", 
                                     nil];
  
  [bundles setValue:topSecrets forKey:@"TOP_SECRETS"];
  
  
  NSMutableDictionary *all = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                              @"All Secrets", @"text",
                              [NSNumber numberWithInt:2], @"rank", 
                              [NSNumber numberWithBool:YES] , @"hideGroups",
                              [NSImage imageNamed:@"NSApplicationIcon"] , @"image",
                              nil];
  
  [bundles setValue:all forKey:@"ALL"];
  
  
  NSMutableDictionary *global = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                 @"System", @"text",
                                 [NSImage imageNamed:@"NSComputer"] , @"image",
                                 [NSNumber numberWithInt:1], @"rank", 
                                 [NSPredicate predicateWithFormat:@"display_bundle like %@",  @".GlobalPreferences"], @"predicate", 
                                 @".GlobalPreferences", @"bundle",
                                 nil];
  
  [bundles setValue:global forKey:@".GlobalPreferences"];
  
  
  NSMutableDictionary *recent = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                 @"New Secrets", @"text",
                                 [NSImage imageNamed:@"NSNetwork"] , @"image",
                                 [NSNumber numberWithBool:YES] , @"globalSearch",
                                 [NSNumber numberWithInt:1], @"rank", 
                                 [NSNumber numberWithBool:YES] , @"hideGroups",
                                 [NSPredicate predicateWithFormat:@"created > %@", previousLaunchDate],  @"predicate",
                                 
                                 nil];
  [bundles setValue:recent forKey:@"Recent"];
  
  
  
  NSArray *launchedApps = [[NSWorkspace sharedWorkspace] launchedApplications];
  NSMutableDictionary *launchedAppsDictionary = [NSMutableDictionary dictionaryWithObjects:launchedApps
                                                                                   forKeys:[launchedApps valueForKey:@"NSApplicationBundleIdentifier"]];
  
  
  // Add dock and frontrow
  [launchedAppsDictionary setObject:[NSDictionary dictionaryWithObjectsAndKeys:@"com.apple.dock", @"NSApplicationBundleIdentifier", nil] 
                             forKey:@"com.apple.dock"];
  [launchedAppsDictionary setObject:[NSDictionary dictionaryWithObjectsAndKeys:@"com.apple.frontrow", @"NSApplicationBundleIdentifier", nil] 
                             forKey:@"com.apple.frontrowlauncher"];
  
  [self setCategories:[bundles allValues]];
  
  NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
  
  for (NSDictionary *entry in  array) {
    
    
    if ([[entry objectForKey:@"hidden"] boolValue]) continue;
    NSString *ident = [entry objectForKey:@"display_bundle"];
    if (!ident) {
      ident = [entry objectForKey:@"bundle"];
      if (ident) [entry setValue:ident forKey:@"display_bundle"];
    }
    
    
    if ([entry objectForKey:@"dangerous"]) {
      [entry setValue:[NSColor colorWithDeviceRed:0.8
                                            green:0.0 blue:0.0 alpha:1.0] forKey:@"textColor"];  
    }
    
    
    if ([entry objectForKey:@"top_secret"]) {
      [entry setValue:[NSColor colorWithDeviceRed:0.0 green:0.0 blue:0.5 alpha:1.0] forKey:@"textColor"];  
    }
    
    if (!ident) continue;
    id bundle = [bundles objectForKey:ident];
    if (!bundle) {
      bundle = [NSMutableDictionary dictionary];
      [bundle setObject: [NSPredicate predicateWithFormat:@"display_bundle like %@", ident] forKey:@"predicate"];
      [bundle setObject:[NSNumber numberWithBool:YES] forKey:@"showGlobals"];
      NSString *name = nil;  
      NSImage *image = nil;
      NSString *path = [workspace absolutePathForAppBundleWithIdentifier:ident];
      
      
      NSDictionary *appDictionary = [launchedAppsDictionary objectForKey:ident];
      if (appDictionary) {
        [bundle setValue:[NSNumber numberWithBool:YES] forKey:@"running"];  
        [bundle setValuesForKeysWithDictionary:appDictionary];
      }
      
      
      if ([ident hasPrefix:@"/"]) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:ident])
          path = ident;
      }
      
      if (path) {
        image = [workspace iconForFile:path];
        name = [[path lastPathComponent] stringByDeletingPathExtension];
      } else {
        [entry setValue:[NSNumber numberWithBool:YES] forKey:@"hidden"];
        continue;
        name = [ident pathExtension];
      }
      
      if (![name length]) name = ident;
      if (!image) image = [NSImage imageNamed:@"NSApplicationIcon"];
      
      
//      NSString *file = [[NSString stringWithFormat:@"~/Desktop/Icons/%@.png", ident] stringByStandardizingPath];
//      [[(NSBitmapImageRep *)[image representationOfSize:NSMakeSize(32, 32)] representationUsingType:NSPNGFileType properties:nil] writeToFile:file atomically:YES];
      
      [bundle setObject:ident forKey:@"bundle"];
      [bundle setObject:image forKey:@"image"];
      [bundle setObject:name forKey:@"text"];
      
      //      [bundle setObject:[NSMutableArray array] forKey:@"contents"];
      [bundles setValue:bundle forKey:ident];  
    }
    
    id values = [entry objectForKey:@"values"];
    if ([values isKindOfClass:[NSString class]]) {
      NSString *errorDescription = nil;
      values = [NSPropertyListSerialization 
                propertyListFromData:[values dataUsingEncoding:NSUTF8StringEncoding]
                mutabilityOption:NSPropertyListImmutable
                format:nil errorDescription:&errorDescription];
      if (errorDescription) NSLog(@"error %@ %@", errorDescription, [entry objectForKey:@"values"]);
      if (values) [entry setValue:values forKey:@"values"];
    }
    [entry setValue:bundle forKey:@"container"];
    
    if (![entry objectForKey:@"title"]) [entry setValue:[entry objectForKey:@"keypath"] forKey:@"title"];
    if (![entry objectForKey:@"title"]) [entry setValue:@"unknown" forKey:@"title"];
    //[[bundle objectForKey:@"contents"] addObject:entry];
  }
  
  [self setCategories:[bundles allValues]];
  if ([[entriesController arrangedObjects] count] > 0)
    [entriesTable noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [[entriesController arrangedObjects] count]-1 )]];
  
}

- (void)columnResized {
  
  if ([[entriesController arrangedObjects] count] > 0)
    [entriesTable noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [[entriesController arrangedObjects] count]-1 )]];
}

- (CGFloat) tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
  if (tableView == categoriesTable) return [tableView rowHeight];
  
  
  NSTableColumn *column = [tableView tableColumnWithIdentifier:@"title"];
  NSCell *cell = [tableView preparedCellAtColumn:[tableView columnWithIdentifier:@"title"] row:row];
  //  NSLog(@"cell %@", cell);
  //	NSString *title = [thisInfo objectForKey:@"title"];
  //  if (!title) title = @"";
  //	[cell setStringValue:title];
  NSSize size = [cell cellSizeForBounds:NSMakeRect(0, 0, [column width] , MAXFLOAT)]; 		
  return MAX([tableView rowHeight], size.height);
}

- (BOOL)tableView:(NSTableView *)tableView shouldShowCellExpansionForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
  return NO; 
}



- (NSString *)tableView:(NSTableView *)aTableView toolTipForCell:(NSCell *)aCell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)row mouseLocation:(NSPoint)mouseLocation { 
  if (aTableView = categoriesTable) return nil;
  id thisInfo = [[entriesController arrangedObjects] objectAtIndex:row];
  
  NSString *tip = [thisInfo objectForKey:@"description"];
  if (![tip length]) return [thisInfo objectForKey:@"title"];
  return tip;
}
- (NSMenu *)menuForValues:(id)items {
  NSMenu *menu = [[[NSMenu alloc] initWithTitle:@""] autorelease];
  
  if ([items isKindOfClass:[NSDictionary class]]) {
    NSArray *keys = [[items allKeys] sortedArrayUsingSelector:@selector(compare:)];
    
    for(NSString *key in keys) {
      NSString *title = key;
      id value = [items objectForKey:key];
      id item = [menu addItemWithTitle:title
                                action:nil
                         keyEquivalent:@""];
      [item setRepresentedObject:value];
    }		
  } else if ([items isKindOfClass: [NSArray class]]) {
    for(id item in items) {
      NSString *title = nil;
      id value = nil;
      
      if ([item isKindOfClass:[NSDictionary class]]) {
        title = [[item allKeys] lastObject];
        value = [item valueForKey:title];
      } else if ([item isKindOfClass:[NSString class]]){
        title = item;
        value = item;
      }
      
      if ([title isEqualToString:@"-"]) {
        [menu addItem:[NSMenuItem separatorItem]];
      } else {
        id menuItem = [menu addItemWithTitle:title
                                      action:nil
                               keyEquivalent:@""];
        [menuItem setRepresentedObject:value];
      }
    }		
  }
  return menu;
}


- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
  
  if ([[tableColumn identifier] isEqualToString:@"group"]) {
    if (row < 1) return;
    id thisObject = [[entriesController arrangedObjects] objectAtIndex:row];
    id lastObject = [[entriesController arrangedObjects] objectAtIndex:row -1];
    if ([[thisObject valueForKey:@"group"] isEqualToString:[lastObject valueForKey:@"group"]]) {
      [cell setStringValue:@""];    
      
    }
  }
  
  if ([[tableColumn identifier] isEqualToString:@"app"]) {
    if (row < 1) return;
    id thisObject = [[entriesController arrangedObjects] objectAtIndex:row];
    id lastObject = [[entriesController arrangedObjects] objectAtIndex:row -1];
    if ([[thisObject valueForKey:@"container"] isEqual:[lastObject valueForKey:@"container"]]) {
      [cell setStringValue:@""];    
      
    }
  }
  
  
  if ([[tableColumn identifier] isEqualToString:@"title"]) {
    if (row >= [[entriesController arrangedObjects] count]) {
      return;
    }  
    id thisInfo = [[entriesController arrangedObjects] objectAtIndex:row]; 	
    
    NSColor * textColor = [thisInfo objectForKey:@"textColor"];
    
    if (row == [tableView selectedRow]) {
      [cell setTextColor:[NSColor alternateSelectedControlTextColor]];
    } else {
      
      [cell setTextColor:textColor ? textColor : [NSColor controlTextColor]];
    }
    
  }
}


- (NSCell *)tableView:(NSTableView *)tableView dataCellForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
  
  if ([[tableColumn identifier] isEqualToString:@"title"]) {
    if (row >= [[entriesController arrangedObjects] count]) {
      return nil;
    }    
    id thisInfo = [[entriesController arrangedObjects] objectAtIndex:row]; 	
    
    
    id value = [self getUserDefaultsValueForInfo:thisInfo];
    
    
    NSCell *cell = [tableColumn dataCell];
    NSFont *font = value ? [NSFont boldSystemFontOfSize:11] : [NSFont systemFontOfSize:11];
    [cell setFont:font];
    return cell;
  }
  
  if (![[tableColumn identifier] isEqualToString:@"value"])
    return [tableColumn dataCellForRow:row];
  if (!tableColumn) return nil;
  id thisInfo = [[entriesController arrangedObjects] objectAtIndex:row];
  NSString *type = [thisInfo objectForKey:@"datatype"];
  NSString *widget = [thisInfo objectForKey:@"widget"];
  
  NSCell *cell = nil;
  if ([type isEqualToString:@"boolean"]
      || [type isEqualToString:@"boolean-neg"]  
      || [type isEqualToString:@"array-add"]
      || [type isEqualToString:@"dict-add"]) {
    cell = [[[NSButtonCell alloc] init] autorelease];
    [cell setAllowsMixedState:YES];
    [(NSButtonCell *)cell setButtonType:NSSwitchButton];
    [cell setTitle:@""];
  }
  
  if ([type isEqualToString:@"array-add-multiple"]) {
    cell = [[[NSButtonCell alloc] init] autorelease];
    [(NSButtonCell *)cell setButtonType:NSOnOffButton];
    [(NSButtonCell *)cell setBezelStyle:NSTexturedRoundedBezelStyle];
    [cell setAlignment:NSLeftTextAlignment];
    id value = [self getUserDefaultsValueForInfo:thisInfo];
    [cell setTitle:value ? @"Add another (delete will remove all)" : @"Add"];
  }
  
  
  
  if ([type isEqualToString:@"path"]) {
    cell = [[NSPathCell alloc] init];
    
    //   [(NSPathCell *)cell setPathStyle:NSPathStylePopUp];//:NSPathStyleNavigationBar];
    [(NSPathCell *)cell setBackgroundColor:[NSColor clearColor]];//:NSPathStyleNavigationBar];
  }
  
  if ([widget hasPrefix:@"popup"]) {
    cell = [[[NSPopUpButtonCell alloc] init] autorelease];
    
    [(NSPopUpButtonCell *)cell setBordered:YES];
    
    [(NSPopUpButtonCell *)cell removeAllItems];
    NSMenu *menu = [self menuForValues:[thisInfo objectForKey:@"values"]];
    [cell setMenu:menu];
  }
  
  if ([widget hasPrefix:@"combo"]) {
    cell = [[[NSComboBoxCell alloc] init] autorelease];
    if ([[thisInfo objectForKey:@"values"] isKindOfClass:[NSArray class]])
      [(NSComboBoxCell *)cell addItemsWithObjectValues:[thisInfo objectForKey:@"values"]];
  }
  
  if (!cell) {
    cell = [[[NSTextFieldCell alloc] init] autorelease];    
    NSString *placeholder = [thisInfo objectForKey:@"placeholder"];
    NSString *units = [thisInfo objectForKey:@"units"];
    
    if (!placeholder) {
      placeholder = type;
      if (units) placeholder = [NSString stringWithFormat:@"%@ (%@)", placeholder, units];
    }
    [(NSTextFieldCell *)cell setPlaceholderString:placeholder];
    
    
    
    
    if (units) {
      NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
      [formatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
      
      NSString *formatterString = [NSString stringWithFormat:@"# %@;;", units];
      
      [formatter setFormat:formatterString];
      
      [cell setFormatter:formatter];
    }
    
  }
  [cell setControlSize:NSSmallControlSize];
  [cell setFont:[NSFont systemFontOfSize:11]];
  [cell setEditable:YES];
  return cell;
}

//- (BOOL)tableView:(NSTableView *)aTableView shouldSelectRow:(int)rowIndex {
//	return YES; 		
//}
//- (BOOL)selectionShouldChangeInTableView:(NSTableView *)aTableView {
//  return YES;  
//}


# pragma mark -
# pragma mark Defaults Getters and Setters

- (id)getUserDefaultsValueForKey:(NSString *)path bundle:(NSString *)bundle user:(CFStringRef)user host:(CFStringRef)host asKeyPath:(BOOL)asKeyPath{
  NSObject *value = nil;
  @try {
    
    
    if ([bundle rangeOfString:@"$HOME"].location != NSNotFound)
      bundle = [bundle stringByReplacingOccurrencesOfString:@"$HOME" withString:NSHomeDirectory()];
    
    NSString *keypath = nil;
    NSString *key = path;
    if (asKeyPath) {
      NSArray *components = [path componentsSeparatedByString:@"."];
      if ([components count] > 1) {
        key = [components objectAtIndex:0];
        keypath = [[components subarrayWithRange:NSMakeRange(1, [components count] - 1)] componentsJoinedByString:@"."];
      }
    }
    if (!key) return nil;
    value = (NSObject *)CFPreferencesCopyValue((CFStringRef)key, (CFStringRef)bundle, user, host);
    [value autorelease];
    
    if (keypath) value = [value valueForKeyPath:keypath];
  }
  
  @catch (NSException *e) {
    NSLog(@"unable to get value: %@", e);
    return nil;
  }
  return value;
}



- (void)setUserDefaultsValue:(id)value forKey:(NSString *)path bundle:(NSString *)bundle user:(CFStringRef)user host:(CFStringRef)host asKeyPath:(BOOL)asKeyPath{
  
  if ([bundle rangeOfString:@"$HOME"].location != NSNotFound)
    bundle = [bundle stringByReplacingOccurrencesOfString:@"$HOME" withString:NSHomeDirectory()];
  
  NSString *keypath = nil;
  NSString *key = path;
  
  if (asKeyPath) {
    NSArray *components = [path componentsSeparatedByString:@"."];
    if ([components count] > 1) {
      key = [components objectAtIndex:0];
      keypath = [[components subarrayWithRange:NSMakeRange(1, [components count] - 1)] componentsJoinedByString:@"."];
    }
  }
  
  NSLog(@"defaults write %@ %@ \"%@\" \"%@\" %@ %@", user, host, bundle, key, keypath ? keypath : @"", value );
  
  if (keypath) { // Handle dictionary subpath
    NSDictionary *dictValue = (NSDictionary *)CFPreferencesCopyValue((CFStringRef)key, (CFStringRef)bundle, user, host);
    [dictValue autorelease];
    if (![dictValue isKindOfClass:[NSDictionary class]]) dictValue = nil;
    
    dictValue = [[dictValue mutableCopy] autorelease];
    if (!dictValue) dictValue = [NSMutableDictionary dictionary];
    [dictValue setValue:value forKeyPath:keypath];
    value = dictValue;
  }
  
  CFPreferencesSetValue((CFStringRef) key, value, (CFStringRef)bundle, user, host);
  CFPreferencesSynchronize((CFStringRef) bundle, user, host);  
  
  if (value)
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"com.blacktree.Secret" object:(NSString *)bundle userInfo:[NSDictionary dictionaryWithObject:value forKey:path]];
  
  
}



- (id)getUserDefaultsValueForInfo:(NSDictionary *)thisInfo {
  NSString *bundle = [thisInfo objectForKey:@"bundle"];
  if ([bundle isEqualToString:@".GlobalPreferences"]) bundle = (NSString *)kCFPreferencesAnyApplication;
  
  NSString *keypath = [thisInfo objectForKey:@"keypath"];
  if (!keypath) return @"";
  
  CFStringRef user = kCFPreferencesCurrentUser;
  CFStringRef host = kCFPreferencesAnyHost;
  if ([[thisInfo objectForKey:@"set_for_all_users"] boolValue]) {
    user = kCFPreferencesAnyUser;
    host = kCFPreferencesCurrentHost;
  }
  if ([[thisInfo objectForKey:@"current_host_only"] boolValue]) host = kCFPreferencesCurrentHost;
  BOOL isKeypath = [[thisInfo objectForKey:@"is_keypath"] boolValue];
  
  
  id value =  [self getUserDefaultsValueForKey:keypath
                                        bundle:bundle 
                                          user:user
                                          host:host
                                     asKeyPath:isKeypath];
  
  NSString *datatype = [thisInfo objectForKey:@"datatype"];
  if ([datatype isEqualToString:@"array-add"] || [datatype isEqualToString:@"array-add-multiple"]) {
    id toggleValue = [thisInfo objectForKey:@"values"];
    if ([value containsObject:toggleValue]) {
      // Return yes if it exists, but if we support multiple, the answer is always NO, but not nil (which is no value set)
      // Delete can clear out all multiple adds
      value = [NSNumber numberWithInt:[datatype isEqualToString:@"array-add-multiple"] ? NO : YES];
    } else {
      value = nil;
    }
  }
  
  if ([datatype isEqualToString:@"dict-add"]) {
    NSDictionary *toggleValue = [thisInfo objectForKey:@"values"];
    
    for (NSString *key in toggleValue) {
      if (![[value valueForKey:key] isEqual:[toggleValue valueForKey:key]]) {
        value = nil;
        break;
      }
      value = [NSNumber numberWithBool:YES];
    }
  }
  
  return value;
  
}

- (void)setUserDefaultsValue:(id)value forInfo:(NSDictionary *)thisInfo {
  CFStringRef user = kCFPreferencesCurrentUser;
  CFStringRef host = kCFPreferencesAnyHost;
  
  if ([[thisInfo objectForKey:@"set_for_all_users"] boolValue]) {
    user = kCFPreferencesAnyUser;
    host = kCFPreferencesCurrentHost;
  }
  if ([[thisInfo objectForKey:@"current_host_only"] boolValue]) host = kCFPreferencesCurrentHost;
  
  NSString *keypath = [thisInfo objectForKey:@"keypath"];
  NSString *bundle = [thisInfo objectForKey:@"bundle"];
  BOOL isKeypath = [[thisInfo objectForKey:@"is_keypath"] boolValue];
  
  
  
  
  id oldValue = [self getUserDefaultsValueForKey:keypath
                                          bundle:bundle
                                            user:user 
                                            host:host 
                                       asKeyPath:isKeypath];
  
  // Inject into an array if for add
  if ([[thisInfo objectForKey:@"datatype"] isEqualToString:@"array-add"]
      || [[thisInfo objectForKey:@"datatype"] isEqualToString:@"array-add-multiple"]) {
    id toggleValue = [thisInfo objectForKey:@"values"];
    
    NSMutableArray  *array = [[oldValue mutableCopy] autorelease];
    
    if ([value boolValue]) {
      if (!array) array = [NSMutableArray array];
      [array addObject:toggleValue];
    } else {
      // The only way this will be reached for array-add-multiple should be value==nil, so clear out
      [array removeObject:toggleValue];
    }
    value = array;
    
  }
  
  // Inject into a dictionary if for add
  if ([[thisInfo objectForKey:@"datatype"] isEqualToString:@"dict-add"]) {
    NSDictionary *toggleValue = [thisInfo objectForKey:@"values"];
    
    NSMutableDictionary  *dict = [[oldValue mutableCopy] autorelease];
    if ([value boolValue]) {
      if (!dict) dict = [NSMutableDictionary dictionary];
      [dict addEntriesFromDictionary:toggleValue];
    } else {
      [dict removeObjectsForKeys:[toggleValue allKeys]];
    }
  }
  
  
  if (![value isEqual:oldValue]) {
    [self setUserDefaultsValue:value
                        forKey:keypath
                        bundle:bundle 
                          user:user
                          host:host
                     asKeyPath:isKeypath];
    
    
    NSString *display_bundle = [thisInfo objectForKey:@"display_bundle"];
    if (!display_bundle ) display_bundle = [thisInfo objectForKey:@"bundle"];
    
    // Mark the bundle as dirty if it is running
    NSDictionary *bundleInfo = [bundles objectForKey:display_bundle];
    if ([bundleInfo valueForKey:@"running"])  
      [bundleInfo setValue:[NSNumber numberWithBool:YES] forKey:@"dirty"];
    
  } else {
    NSLog(@"value stayed the same"); 
  }
  
  
  
  
}


- (IBAction)resetValue:(id)sender {
  id thisInfo = [[entriesController arrangedObjects] objectAtIndex:[entriesTable selectedRow]]; 
  [self setUserDefaultsValue:nil forInfo:thisInfo];
  [entriesTable display];
}


- (NSRect)splitView:(NSSplitView *)splitView 
      effectiveRect:(NSRect)proposedEffectiveRect 
       forDrawnRect:(NSRect)drawnRect
   ofDividerAtIndex:(NSInteger)dividerIndex {
  drawnRect.size.height = splitView.frame.size.height - drawnRect.origin.y;
  return drawnRect;
}

- (CGFloat)splitView:(NSSplitView *)sender constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)offset {
  return sender.frame.size.height - 81;  
}
- (CGFloat)splitView:(NSSplitView *)sender constrainMaxCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)offset {
  return sender.frame.size.height - 20;  
}

#pragma mark -

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
  if ([[aTableColumn identifier] isEqualToString:@"icon"]) {
    id thisInfo = [[entriesController arrangedObjects] objectAtIndex:rowIndex]; 	
    NSString *ident = [thisInfo objectForKey:@"display_bundle"];
    if (!ident) ident = [thisInfo objectForKey:@"bundle"];
    
    //    if ([ident isEqualToString:@".GlobalPreferences"]) {
    //      id category = [[categoriesController selectedObjects] lastObject];
    //      ident = [category valueForKey:@"bundle"];
    //      NSLog(@"ident %@", category);
    //    }
    return [[bundles objectForKey:ident] objectForKey:@"image"];
  }
  
  if ([[aTableColumn identifier] isEqualToString:@"value"]) {
    id thisInfo = [[entriesController arrangedObjects] objectAtIndex:rowIndex]; 	
    
    id value = [self getUserDefaultsValueForInfo:thisInfo];
    
    if (!value) {
      value = [thisInfo objectForKey:@"defaultvalue"];
    }
    NSString *datatype = [thisInfo objectForKey:@"datatype"];
    
    if ([datatype isEqualToString:@"boolean"])
      value = [NSNumber numberWithBool:[(NSNumber *)value boolValue]];
    
    if ([datatype isEqualToString:@"boolean-neg"])
      value = [NSNumber numberWithBool:![(NSNumber *)value boolValue]];
    
    //    if ([datatype isEqualToString:@"array-add"]) {
    //      id toggleValue = [thisInfo objectForKey:@"values"];
    //      NSLog(@" %@ contains %@" , value, toggleValue);
    //      value = [NSNumber numberWithBool:[value containsObject:toggleValue]];
    //    }
    
    
    
    if ([[thisInfo objectForKey:@"widget"] isEqualToString:@"popup"]) {
      NSMenu *menu = [self menuForValues:[thisInfo objectForKey:@"values"]];
      if ([value isKindOfClass:[NSNumber class]]) value = [value stringValue];
      int index = [menu indexOfItemWithRepresentedObject:value];
      value = [NSNumber numberWithInt:index];
    }
    
    return value;
  }
  return nil;
}

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)value forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
  if ([[aTableColumn identifier] isEqualToString:@"value"]) {
    id thisInfo = [[entriesController arrangedObjects] objectAtIndex:rowIndex]; 	    
    if ([value isKindOfClass:[NSString class]] && ![value length]) value = nil;
    if ([[thisInfo objectForKey:@"widget"] isEqualToString:@"popup"]) {
      NSMenu *menu = [self menuForValues:[thisInfo objectForKey:@"values"]];
      value = [[menu itemAtIndex:[value intValue]] representedObject];
    }
    
    NSString *datatype = [thisInfo objectForKey:@"datatype"];
    
    if ([datatype isEqualToString:@"float"]) {
      value = [NSNumber numberWithFloat:[value floatValue]];
    }
    
    if ([datatype isEqualToString:@"integer"]) {
      value = [NSNumber numberWithInt:[value intValue]];
    }
    
    if ([datatype isEqualToString:@"boolean-neg"])
      value = [NSNumber numberWithBool:![value boolValue]];
    
    if ([value isKindOfClass:[NSString class]] && ![(NSString *)value length]) {
      value = nil;
    }
    
    [self setUserDefaultsValue:value forInfo:thisInfo];
    [aTableView display];
    
  }
}

- (void)setSearchPredicate:(NSPredicate *)newSearchPredicate {
  if (searchPredicate != newSearchPredicate) {
    [searchPredicate autorelease];
    searchPredicate = [newSearchPredicate retain];
    [self updateEntries];
  }
}

- (void)updateEntries {
  id category = [[categoriesController selectedObjects] lastObject];
  
  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"hidden != 1"];
  if (searchPredicate) predicate = [NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObjects:predicate, searchPredicate, nil]];
  
  NSString *domain = [category valueForKey:@"bundle"];
  if (domain) CFPreferencesAppSynchronize((CFStringRef)domain);
  
  NSPredicate *categoryPredicate = [category valueForKey:@"predicate"];
  
  // Don't show globals for now
  //  if (categoryPredicate && [category valueForKey:@"showGlobals"] ) {
  //    categoryPredicate = [NSCompoundPredicate orPredicateWithSubpredicates:[NSArray arrayWithObjects:
  //                         categoryPredicate,
  //                         [NSPredicate predicateWithFormat:@"bundle = '.GlobalPreferences'"], nil
  //                         ]];
  //                                                                                             
  //  }
  
  BOOL shouldSearchGlobally = ([[category valueForKey:@"globalSearch"] boolValue] && searchPredicate);
  if (categoryPredicate && !shouldSearchGlobally) {
    predicate = [NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObjects:predicate, categoryPredicate, nil]];
  }
  
  [entriesController setFilterPredicate:predicate];
  
  [self setShowInfo:category == nil];
  
  BOOL hasGroups = [[[entriesController arrangedObjects] valueForKeyPath:@"@distinctUnionOfObjects.group"] count] > 1;
  
  @try {
    NSTableColumn *appColumn = [entriesTable tableColumnWithIdentifier:@"app"];
    [appColumn setHidden:![[category valueForKey:@"hideGroups"] boolValue]];
    
    NSTableColumn *iconColumn = [entriesTable tableColumnWithIdentifier:@"icon"];
    [iconColumn setHidden:hasGroups && ![[category valueForKey:@"hideGroups"] boolValue]];
    
    NSTableColumn *groupColumn = [entriesTable tableColumnWithIdentifier:@"group"];
    [groupColumn setHidden:!hasGroups || [[category valueForKey:@"hideGroups"] boolValue]];
  }
  @catch (NSException *e) {
    NSLog(@"error: %@", [e callStackReturnAddresses]);  
  }
  
  [entriesTable reloadData];
  if ([[entriesController arrangedObjects] count])
    [entriesTable noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [[entriesController arrangedObjects] count]-1 )]];
  
  
}

- (void)tableViewSelectionIsChanging:(NSNotification *)notification {
  if ([notification object] == categoriesTable) {
    int row = [categoriesTable selectedRow];
    id thisInfo = [[categoriesController arrangedObjects] objectAtIndex: row]; 	
    
    [categoriesController setSelectedObjects:[NSArray arrayWithObject:thisInfo]];
    [self updateEntries];
    
    self.searchPredicate = nil;
    
  }
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
  if ([notification object] == categoriesTable) {
    self.searchPredicate = nil;
    [self updateEntries];
  }  
}



#pragma mark -
#pragma mark Connection

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
  if (fetchData) {
    NSString *error = nil;
    NSArray *array = [NSPropertyListSerialization 
                      propertyListFromData:fetchData
                      mutabilityOption:NSPropertyListMutableContainers
                      format:nil errorDescription:&error];
    
    if (error) {
      
      NSAlert *errorAlert = [NSAlert alertWithMessageText:@"Update Error"
                                            defaultButton:@"OK" 
                                          alternateButton:nil
                                              otherButton:nil
                                informativeTextWithFormat:@"Data was corrupted: %@", error];
      
      [errorAlert beginSheetModalForWindow:[[self mainView] window]
                             modalDelegate:self 
                            didEndSelector:NULL
                               contextInfo:NULL];
      NSLog(@"Error loading plist: %@", error);
    } else {
      NSString *path = [@"~/Library/Caches/Secrets.plist" stringByStandardizingPath];
      [array writeToFile:path atomically:YES];  
    }
    
  }
  
  
  self.fetchConnection = nil;
  self.fetchData = nil;
  
  [self loadInfo:nil];
  [progressIndicator stopAnimation:nil];
}

- (void)connection:(NSURLConnection *)connection
  didFailWithError:(NSError *)error {
  self.fetchConnection = nil;
  self.fetchData = nil;
  [progressIndicator stopAnimation:nil];
  
  NSAlert *errorAlert = [NSAlert alertWithMessageText:@"Update Error"
                                        defaultButton:@"OK" 
                                      alternateButton:nil
                                          otherButton:nil
                            informativeTextWithFormat:@"Could not download latest data: %@", [error localizedDescription]];
  
  [errorAlert beginSheetModalForWindow:[[self mainView] window]
                         modalDelegate:self 
                        didEndSelector:NULL
                           contextInfo:NULL];
  
  NSLog(@"Connection failed! Error - %@ %@",
        [error localizedDescription],
        [[error userInfo] objectForKey:NSErrorFailingURLStringKey]);
}

- (IBAction)showHelp:(id)sender {
  if ([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask)
  {
	  NSBundle *bundle = [NSBundle bundleForClass:[self class]];
	  NSAlert *showVersion = [NSAlert alertWithMessageText:@"About Secrets" 
											 defaultButton:@"OK" 
										   alternateButton:nil
											   otherButton:nil 
								 informativeTextWithFormat:@"Version: %@", [bundle objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey]];
	  NSImage *secretsIcon = [[NSImage alloc] initWithContentsOfFile:[bundle pathForResource:@"Secrets" ofType:@"icns"]];
	  [showVersion setIcon:secretsIcon];
	  [showVersion runModal];
	  [secretsIcon release];
	  return;
  }
  [[NSWorkspace sharedWorkspace] openURL:kSecretsHelpURL];
}

- (IBAction)showSite:(id)sender {
  NSURL *url = kSecretsSiteURL;
  [[NSWorkspace sharedWorkspace] openURL:url];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSHTTPURLResponse *)response {
  
  NSInteger statusCode = [response statusCode];
  if (statusCode >= 400) {
    [connection cancel];
    [self connection:connection didFailWithError:[NSError errorWithDomain:@"HTTP Status" code:500 userInfo:
                                                  [NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedDescriptionKey,[NSHTTPURLResponse localizedStringForStatusCode:500], nil]]];
    
  }
  
  
  
  NSString *version = [[response allHeaderFields] valueForKey:@"Secrets-Version"];
  NSString *message = [[response allHeaderFields] valueForKey:@"Secrets-Message"];
  NSString *currentVersion = [[NSBundle bundleForClass:[self class]] objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey];
  if (!message) message = @"";
  
  if ([version compare:currentVersion]) {
    NSLog(@"Version updated %@ -> %@", currentVersion, version);
    NSAlert *updateAlert = [NSAlert alertWithMessageText:@"Update available!"
                                           defaultButton:@"Get it!" 
                                         alternateButton:@"Later" 
                                             otherButton:nil
                               informativeTextWithFormat:@"Secrets %@ has been released. %@", version, message];
    
    [updateAlert beginSheetModalForWindow:[[self mainView] window]
                            modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:)
                              contextInfo:[version retain]];
    
  }
  [fetchData setLength:0];
}

- (void)alertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
  if (returnCode) {
    [[NSWorkspace sharedWorkspace] openURL:kSecretsSiteURL];
    NSString *myPath = [[NSBundle bundleForClass:[self class]] bundlePath];
    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:myPath error:&error];
    if (error) NSLog(@"Remove error %@", error);
    [NSApp terminate:nil];
  }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
  [fetchData appendData:data];
}

- (void)dealloc
{
  [self setCategories: nil];
  [self setEntries: nil];
  [self setCurrentEntry: nil];
  [super dealloc];
}

@end
