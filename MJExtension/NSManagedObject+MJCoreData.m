//
//  NSManagedObject+MJCoreData.m
//  MJExtensionExample
//
//  Created by 陆晖 on 15/10/30.
//  Copyright © 2015年 小码哥. All rights reserved.
//

#import "NSManagedObject+MJCoreData.h"
#import "NSObject+MJClass.h"

@interface NSObject (MJClassPrivate)

+ (NSMutableArray *)totalObjectsWithSelector:(SEL)selector key:(const char *)key;

@end

static const char MJCoreDataIdentityKey = '\0';

@implementation NSManagedObject (MJCoreData)

+ (void)setupIdentityPropertyNames:(MJIdentityPropertyNames)ientityPropertyNames {
    [self setupBlockReturnValue:ientityPropertyNames key:&MJCoreDataIdentityKey];
}

+ (NSMutableArray *)totalIdentityPropertyNames {
    return [self totalObjectsWithSelector:@selector(identityPropertyNames) key:&MJCoreDataIdentityKey];
}

@end
