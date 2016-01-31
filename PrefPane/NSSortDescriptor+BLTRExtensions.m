//
//  NSSortDescriptor+BLTRExtensions.m
//  Quicksilver
//
//  Created by Alcor on 3/27/05.

//

#import "NSSortDescriptor+BLTRExtensions.h"


@implementation NSSortDescriptor (QSConvenience)
+ (id)descriptorWithKey:(NSString *)key ascending:(BOOL)ascending{
	return[[NSSortDescriptor alloc] initWithKey:key ascending:ascending];
}
+ (id)descriptorWithKey:(NSString *)key ascending:(BOOL)ascending selector:(SEL)selector{
	return[[NSSortDescriptor alloc] initWithKey:key ascending:ascending selector:(SEL)selector];
}
+ (NSArray *)descriptorArrayWithKey:(NSString *)key ascending:(BOOL)ascending{
	id descriptor=[[NSSortDescriptor alloc] initWithKey:key ascending:ascending];
	return [NSArray arrayWithObject:descriptor];	
}

+ (NSArray *)descriptorArrayWithKey:(NSString *)key ascending:(BOOL)ascending selector:(SEL)selector{
	id descriptor=[[NSSortDescriptor alloc] initWithKey:key ascending:ascending selector:(SEL)selector];
	return [NSArray arrayWithObject:descriptor];	
}
@end
