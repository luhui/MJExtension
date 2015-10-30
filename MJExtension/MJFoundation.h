//
//  MJFoundation.h
//  MJExtensionExample
//
//  Created by MJ Lee on 14/7/16.
//  Copyright (c) 2014年 小码哥. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MJFoundation : NSObject
+ (BOOL)isClassFromFoundation:(Class)c;
/**
 *  是否是容器，NSArray, NSSet, NSOrderSet
 */
+ (BOOL)isCollectionClass:(Class)c;
@end
