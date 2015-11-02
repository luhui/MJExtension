//
//  NSObject+MJClass.h
//  MJExtensionExample
//
//  Created by MJ Lee on 15/8/11.
//  Copyright (c) 2015年 小码哥. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 *  遍历所有类的block（父类）
 */
typedef void (^MJClassesEnumeration)(Class c, BOOL *stop);

/** 这个数组中的属性名才会进行字典和模型的转换 */
typedef NSArray * (^MJAllowedPropertyNames)();
/** 这个数组中的属性名才会进行归档 */
typedef NSArray * (^MJAllowedCodingPropertyNames)();

/** 这个数组中的属性名将会被忽略：不进行字典和模型的转换 */
typedef NSArray * (^MJIgnoredPropertyNames)();
/** 这个数组中的属性名将会被忽略：不进行归档 */
typedef NSArray * (^MJIgnoredCodingPropertyNames)();

/** 这个数组中的属性名才会进行JSON序列化 */
typedef NSArray * (^MJJSONSerializationPropertyNames)();
/** 这个数组中的属性名才会序列化到object中 */
typedef NSArray * (^MJObjectMappingPropertyNames)();

/** 这个数组中的属性名会被忽略：不会进行JSON序列化 */
typedef NSArray * (^MJIgnoredJSONSerializationPropertyNames)();
/** 这个数组中的属性名会被忽略：才会序列化到object中 */
typedef NSArray * (^MJIgnoredObjectMappingPropertyNames)();

/**
 * 类相关的扩展
 */
@interface NSObject (MJClass)
/**
 *  遍历所有的类
 */
+ (void)enumerateClasses:(MJClassesEnumeration)enumeration;
+ (void)enumerateAllClasses:(MJClassesEnumeration)enumeration;

#pragma mark - 属性白名单配置
/**
 *  这个数组中的属性名才会进行字典和模型的转换
 *
 *  @param allowedPropertyNames          这个数组中的属性名才会进行字典和模型的转换
 */
+ (void)setupAllowedPropertyNames:(MJAllowedPropertyNames)allowedPropertyNames;

/**
 *  这个数组中的属性名才会进行字典和模型的转换
 */
+ (NSMutableArray *)totalAllowedPropertyNames;

#pragma mark - 属性黑名单配置
/**
 *  这个数组中的属性名将会被忽略：不进行字典和模型的转换
 *
 *  @param ignoredPropertyNames          这个数组中的属性名将会被忽略：不进行字典和模型的转换
 */
+ (void)setupIgnoredPropertyNames:(MJIgnoredPropertyNames)ignoredPropertyNames;

/**
 *  这个数组中的属性名将会被忽略：不进行字典和模型的转换
 */
+ (NSMutableArray *)totalIgnoredPropertyNames;

#pragma mark - 归档属性白名单配置
/**
 *  这个数组中的属性名才会进行归档
 *
 *  @param allowedCodingPropertyNames          这个数组中的属性名才会进行归档
 */
+ (void)setupAllowedCodingPropertyNames:(MJAllowedCodingPropertyNames)allowedCodingPropertyNames;

/**
 *  这个数组中的属性名才会进行字典和模型的转换
 */
+ (NSMutableArray *)totalAllowedCodingPropertyNames;

#pragma mark - 归档属性黑名单配置
/**
 *  这个数组中的属性名将会被忽略：不进行归档
 *
 *  @param ignoredCodingPropertyNames          这个数组中的属性名将会被忽略：不进行归档
 */
+ (void)setupIgnoredCodingPropertyNames:(MJIgnoredCodingPropertyNames)ignoredCodingPropertyNames;

/**
 *  这个数组中的属性名将会被忽略：不进行归档
 */
+ (NSMutableArray *)totalIgnoredCodingPropertyNames;

#pragma mark - 序列化映射白名单配置
/**
 *  这个数组中的属性名才会进行JSON序列化
 *
 *  @param ignoredCodingPropertyNames          这个数组中的属性名将会被忽略：不进行归档
 */
+ (void)setupJSONSerializationPropertyNames:(MJJSONSerializationPropertyNames)jsonSerializationPropertyNames;

/**
 *  这个数组中的属性名将会被忽略：不进行归档
 */
+ (NSMutableArray *)totalJSONSerializationPropertyNames;
/**
 *  这个数组中的属性名才会序列化到object中
 *
 *  @param ignoredCodingPropertyNames          这个数组中的属性名将会被忽略：不进行归档
 */
+ (void)setupObjectMappingPropertyNames:(MJObjectMappingPropertyNames)objectMappingPropertyNames;

/**
 *  这个数组中的属性名才会序列化到object中
 */
+ (NSMutableArray *)totalObjectMappingPropertyNames;

#pragma mark - 序列化黑名单配置

/**
 * 这个数组中的属性名会被忽略：不会序列化到object中
*/
+ (void)setupIgnoreObjectMappingPropertyNames:(MJIgnoredObjectMappingPropertyNames)ignoredObjectMappingPropertyNames;

/**
 * 这个数组中的属性名会被忽略：不会序列化到object中
 */
+ (NSMutableArray *)totalIgnoredObjectMappingPropertyNames;

/*
 * 这个数组中的属性名会被忽略：不会进行JSON序列化
 */
+ (void)setupIgnoredJSONSerializationPropertyNames:(MJIgnoredJSONSerializationPropertyNames)ignoredJSONSerializationPropertyNames;

/*
 * 这个数组中的属性名会被忽略：不会进行JSON序列化 
 */
+ (NSMutableArray *)totalIgnoredJSONSerializationPropertyNames;

#pragma mark - 内部使用
+ (void)setupBlockReturnValue:(id (^)())block key:(const char *)key;
@end
