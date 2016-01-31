//
//  SecretsPref.h
//  Secrets
//
//  Created by Nicholas Jitkoff on 9/9/06.


#import <PreferencePanes/PreferencePanes.h>


@interface SecretsPref : NSPreferencePane 
{
  IBOutlet NSView *sidebarView;
  
  NSArray *categories;
  NSMutableDictionary *bundles;
  NSArray *entries;
  
  IBOutlet NSDictionary *sourcesDictionary;
  
  IBOutlet NSArrayController *categoriesController;
  IBOutlet NSTableView  *categoriesTable;
  IBOutlet NSArrayController *entriesController;
  IBOutlet NSTableView  *entriesTable;
  
  IBOutlet NSPanel *sourcesPanel;
  
  NSDictionary *currentEntry;
  IBOutlet NSProgressIndicator *progressIndicator;
  IBOutlet NSTextField *progressField;
  IBOutlet NSTextField *searchField;
  BOOL downloading;
  BOOL showInfo;
  NSDate *previousLaunchDate;
  NSURLConnection *fetchConnection;
  NSMutableData   *fetchData;
  NSPredicate *searchPredicate;
}

@property(retain) NSURLConnection *fetchConnection;
@property(retain) NSMutableData   *fetchData;
@property(retain) NSArray *entries;
@property(retain) NSArray *categories;
@property(retain) NSMutableDictionary *bundles;
@property(retain) NSDictionary *currentEntry;
@property(retain) NSPredicate *searchPredicate;
@property(assign) BOOL showInfo;

- (IBAction)reloadInfo:(id)sender;
- (IBAction)showSite:(id)sender;
- (IBAction)showHelp:(id)sender;
- (IBAction)loadInfo:(id)sender;
- (IBAction)resetValue:(id)sender;
- (IBAction)openEntry:(id)sender;

- (IBAction)quitEntry:(id)sender;

- (BOOL) showInfo;
- (void) setShowInfo: (BOOL) flag;


@end
