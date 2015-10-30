//
//  NSObject+MJKeyValue.m
//  MJExtension
//
//  Created by mj on 13-8-24.
//  Copyright (c) 2013年 小码哥. All rights reserved.
//

#import "NSObject+MJKeyValue.h"
#import "NSObject+MJProperty.h"
#import "NSString+MJExtension.h"
#import "MJProperty.h"
#import "MJPropertyType.h"
#import "MJExtensionConst.h"
#import "MJFoundation.h"
#import "NSString+MJExtension.h"
#import "NSObject+MJClass.h"
#import "NSManagedObject+MJCoreData.h"

@interface NSManagedObject (MJKeyValue)

+ (NSArray *)defaultAllowPropertyNamesWithContext:(NSManagedObjectContext *)context error:(NSError **)error;

@end

@implementation NSObject (MJKeyValue)

#pragma mark - 模型 -> 字典时的参考
/** 模型转字典时，字典的key是否参考replacedKeyFromPropertyName等方法（父类设置了，子类也会继承下来） */
static const char MJReferenceReplacedKeyWhenCreatingKeyValuesKey = '\0';

+ (void)referenceReplacedKeyWhenCreatingKeyValues:(BOOL)reference
{
    objc_setAssociatedObject(self, &MJReferenceReplacedKeyWhenCreatingKeyValuesKey, @(reference), OBJC_ASSOCIATION_ASSIGN);
}

+ (BOOL)isReferenceReplacedKeyWhenCreatingKeyValues
{
    __block id value = objc_getAssociatedObject(self, &MJReferenceReplacedKeyWhenCreatingKeyValuesKey);
    if (!value) {
        [self enumerateAllClasses:^(__unsafe_unretained Class c, BOOL *stop) {
            value = objc_getAssociatedObject(c, &MJReferenceReplacedKeyWhenCreatingKeyValuesKey);
            
            if (value) *stop = YES;
        }];
    }
    return [value boolValue];
}

#pragma mark - --常用的对象--
static NSNumberFormatter *numberFormatter_;
+ (void)load
{
    numberFormatter_ = [[NSNumberFormatter alloc] init];
}

#pragma mark - --公共方法--
#pragma mark - 字典 -> 模型
- (instancetype)setKeyValues:(id)keyValues
{
    return [self setKeyValues:keyValues error:nil];
}

- (instancetype)setKeyValues:(id)keyValues error:(NSError *__autoreleasing *)error
{
    return [self setKeyValues:keyValues context:nil error:error];
}

- (instancetype)setKeyValues:(id)keyValues context:(NSManagedObjectContext *)context
{
    return [self setKeyValues:keyValues context:context error:nil];
}

/**
 核心代码：
 */
- (instancetype)setKeyValues:(id)keyValues context:(NSManagedObjectContext *)context error:(NSError *__autoreleasing *)error
{
    // 获得JSON对象
    keyValues = [keyValues JSONObject];
    
    MJExtensionAssertError([keyValues isKindOfClass:[NSDictionary class]], self, error, @"keyValues参数不是一个字典");
    
    Class aClass = [self class];
    NSArray *allowedPropertyNames = [aClass totalAllowedPropertyNames];
    if ([self isKindOfClass:[NSManagedObject class]] && allowedPropertyNames.count == 0) {
        allowedPropertyNames = [aClass defaultAllowPropertyNamesWithContext:context error:error];
        //加入缓存
        [aClass setupAllowedPropertyNames:^NSArray *{
            return allowedPropertyNames;
        }];
    }
    NSArray *ignoredPropertyNames = [aClass totalIgnoredPropertyNames];
        
        //通过封装的方法回调一个通过运行时编写的，用于返回属性列表的方法。
    [aClass enumerateProperties:^(MJProperty *property, BOOL *stop) {
        @try {
            // 0.检测是否被忽略
            if (allowedPropertyNames.count && ![allowedPropertyNames containsObject:property.name]) return;
            if ([ignoredPropertyNames containsObject:property.name]) return;
            
            // 1.取出属性值
            id value;
            NSArray *propertyKeyses = [property propertyKeysForClass:aClass];
            for (NSArray *propertyKeys in propertyKeyses) {
                value = keyValues;
                for (MJPropertyKey *propertyKey in propertyKeys) {
                    value = [propertyKey valueInObject:value];
                }
                if (value) break;
            }
            
            // 值的过滤
            id newValue = [aClass getNewValueFromObject:self oldValue:value property:property];
            if (newValue) value = newValue;
            
            // 如果没有值，就直接返回
            if (!value || value == [NSNull null]) return;
            
            // 2.如果是模型属性
            MJPropertyType *type = property.type;
            Class typeClass = type.typeClass;
            Class objectClass = [property objectClassInArrayForClass:[self class]];
            if (!type.isFromFoundation && typeClass) {
                value = [typeClass objectWithKeyValues:value context:context error:error];
            } else if (objectClass) {
                // string array -> url array
                if (objectClass == [NSURL class] && [value isKindOfClass:[NSArray class]]) {
                    NSMutableArray *urlArray = [NSMutableArray array];
                    for (NSString *string in value) {
                        if (![string isKindOfClass:[NSString class]]) continue;
                        [urlArray addObject:string.url];
                    }
                    value = urlArray;
                } else {
                    // 3.字典数组-->模型数组
                    if ([typeClass isSubclassOfClass:[NSSet class]]) {
                        value = [objectClass objectSetWithKeyValuesArray:value context:context error:error];
                    } else if ([type isKindOfClass:[NSOrderedSet class]]) {
                        value = [objectClass objectOrderedSetWithKeyValuesArray:value context:context error:error];
                    } else {
                        value = [objectClass objectArrayWithKeyValuesArray:value context:context error:error];
                    }
                }
            } else if (typeClass == [NSString class]) {
                if ([value isKindOfClass:[NSNumber class]]) {
                    // NSNumber -> NSString
                    value = [value description];
                } else if ([value isKindOfClass:[NSURL class]]) {
                    // NSURL -> NSString
                    value = [value absoluteString];
                }
            } else if ([value isKindOfClass:[NSString class]]) {
                if (typeClass == [NSURL class]) {
                    // NSString -> NSURL
                    // 字符串转码
                    value = [value url];
                } else if (type.isNumberType) {
                    NSString *oldValue = value;
                    
                    // NSString -> NSNumber
                    value = [numberFormatter_ numberFromString:oldValue];
                    
                    // 如果是BOOL
                    if (type.isBoolType) {
                        // 字符串转BOOL（字符串没有charValue方法）
                        // 系统会调用字符串的charValue转为BOOL类型
                        NSString *lower = [oldValue lowercaseString];
                        if ([lower isEqualToString:@"yes"] || [lower isEqualToString:@"true"]) {
                            value = @YES;
                        } else if ([lower isEqualToString:@"no"] || [lower isEqualToString:@"false"]) {
                            value = @NO;
                        }
                    }
                }
            }
            
            // 4.赋值
            [property setValue:value forObject:self];
        } @catch (NSException *exception) {
            MJExtensionBuildError(error, exception.reason);
            NSLog(@"%@", exception);
        }
    }];
    
    // 转换完毕
    if ([self respondsToSelector:@selector(keyValuesDidFinishConvertingToObject)]) {
        [self keyValuesDidFinishConvertingToObject];
    }
    return self;
}

+ (instancetype)objectWithKeyValues:(id)keyValues
{
    return [self objectWithKeyValues:keyValues error:nil];
}

+ (instancetype)objectWithKeyValues:(id)keyValues error:(NSError *__autoreleasing *)error
{
    return [self objectWithKeyValues:keyValues context:nil error:error];
}

+ (instancetype)objectWithKeyValues:(id)keyValues context:(NSManagedObjectContext *)context
{
    return [self objectWithKeyValues:keyValues context:context error:nil];
}

+ (instancetype)objectWithKeyValues:(id)keyValues context:(NSManagedObjectContext *)context error:(NSError *__autoreleasing *)error
{
    if (keyValues == nil) return nil;
    NSObject *data =[self generateDataWithKeyValue:keyValues inContext:context error:error];
    return [data setKeyValues:keyValues context:context error:error];
}

+ (instancetype)objectWithFilename:(NSString *)filename
{
    return [self objectWithFilename:filename error:nil];
}

+ (instancetype)objectWithFilename:(NSString *)filename error:(NSError *__autoreleasing *)error
{
    MJExtensionAssertError(filename != nil, nil, error, @"filename参数为nil");
    
    return [self objectWithFile:[[NSBundle mainBundle] pathForResource:filename ofType:nil] error:error];
}

+ (instancetype)objectWithFile:(NSString *)file
{
    return [self objectWithFile:file error:nil];
}

+ (instancetype)objectWithFile:(NSString *)file error:(NSError *__autoreleasing *)error
{
    MJExtensionAssertError(file != nil, nil, error, @"file参数为nil");
    
    return [self objectWithKeyValues:[NSDictionary dictionaryWithContentsOfFile:file] error:error];
}

#pragma mark - 字典数组 -> 模型数组

#pragma mark Array

+ (NSMutableArray *)objectArrayWithKeyValuesArray:(NSArray *)keyValuesArray
{
    return [self objectArrayWithKeyValuesArray:keyValuesArray error:nil];
}

+ (NSMutableArray *)objectArrayWithKeyValuesArray:(NSArray *)keyValuesArray error:(NSError *__autoreleasing *)error
{
    return [self objectArrayWithKeyValuesArray:keyValuesArray context:nil error:error];
}

+ (NSMutableArray *)objectArrayWithKeyValuesArray:(id)keyValuesArray context:(NSManagedObjectContext *)context
{
    return [self objectArrayWithKeyValuesArray:keyValuesArray context:context error:nil];
}

+ (NSMutableArray *)objectArrayWithKeyValuesArray:(id)keyValuesArray context:(NSManagedObjectContext *)context error:(NSError *__autoreleasing *)error
{
    return [self objectMutableCollection:[NSMutableArray new] withKeyValuesArray:keyValuesArray context:context error:error];
}

#pragma mark Set

+ (NSMutableSet *)objectSetWithKeyValuesArray:(id)keyValuesArray {
    return [self objectSetWithKeyValuesArray:keyValuesArray context:nil error:NULL];
}

+ (NSMutableSet *)objectSetWithKeyValuesArray:(id)keyValuesArray error:(NSError *__autoreleasing *)error {
    return [self objectSetWithKeyValuesArray:keyValuesArray context:NULL error:error];
}

+ (NSMutableSet *)objectSetWithKeyValuesArray:(id)keyValuesArray context:(NSManagedObjectContext *)context {
    return [self objectSetWithKeyValuesArray:keyValuesArray context:context error:NULL];
}

+ (NSMutableSet *)objectSetWithKeyValuesArray:(id)keyValuesArray context:(NSManagedObjectContext *)context error:(NSError *__autoreleasing *)error {
    return [self objectMutableCollection:[NSMutableSet new] withKeyValuesArray:keyValuesArray context:context error:error];
}

#pragma mark OrderdSet

+ (NSMutableOrderedSet *)objectOrderedSetWithKeyValuesArray:(id)keyValuesArray {
    return [self objectOrderedSetWithKeyValuesArray:keyValuesArray context:nil error:NULL];
}

+ (NSMutableOrderedSet *)objectOrderedSetWithKeyValuesArray:(id)keyValuesArray error:(NSError *__autoreleasing *)error {
    return [self objectOrderedSetWithKeyValuesArray:keyValuesArray context:nil error:error];
}

+ (NSMutableOrderedSet *)objectOrderedSetWithKeyValuesArray:(id)keyValuesArray context:(NSManagedObjectContext *)context {
    return [self objectOrderedSetWithKeyValuesArray:keyValuesArray context:context error:NULL];
}

+ (NSMutableOrderedSet *)objectOrderedSetWithKeyValuesArray:(id)keyValuesArray context:(NSManagedObjectContext *)context error:(NSError *__autoreleasing *)error {
    return [self objectMutableCollection:[NSMutableOrderedSet new] withKeyValuesArray:keyValuesArray context:context error:error];
}

+ (NSMutableArray *)objectArrayWithFilename:(NSString *)filename
{
    return [self objectArrayWithFilename:filename error:nil];
}

+ (NSMutableArray *)objectArrayWithFilename:(NSString *)filename error:(NSError *__autoreleasing *)error
{
    MJExtensionAssertError(filename != nil, nil, error, @"filename参数为nil");
    
    return [self objectArrayWithFile:[[NSBundle mainBundle] pathForResource:filename ofType:nil] error:error];
}

+ (NSMutableArray *)objectArrayWithFile:(NSString *)file
{
    return [self objectArrayWithFile:file error:nil];
}

+ (NSMutableArray *)objectArrayWithFile:(NSString *)file error:(NSError *__autoreleasing *)error
{
    MJExtensionAssertError(file != nil, nil, error, @"file参数为nil");
    
    return [self objectArrayWithKeyValuesArray:[NSArray arrayWithContentsOfFile:file] error:error];
}

#pragma mark - 模型 -> 字典
- (NSMutableDictionary *)keyValues
{
    return [self keyValuesWithError:nil];
}

- (NSMutableDictionary *)keyValuesWithError:(NSError *__autoreleasing *)error
{
    return [self keyValuesWithIgnoredKeys:nil error:error];
}

- (NSMutableDictionary *)keyValuesWithKeys:(NSArray *)keys
{
    return [self keyValuesWithKeys:keys error:nil];
}

- (NSMutableDictionary *)keyValuesWithKeys:(NSArray *)keys error:(NSError *__autoreleasing *)error
{
    return [self keyValuesWithKeys:keys ignoredKeys:nil error:error];
}

- (NSMutableDictionary *)keyValuesWithIgnoredKeys:(NSArray *)ignoredKeys
{
    return [self keyValuesWithIgnoredKeys:ignoredKeys error:nil];
}

- (NSMutableDictionary *)keyValuesWithIgnoredKeys:(NSArray *)ignoredKeys error:(NSError *__autoreleasing *)error
{
    return [self keyValuesWithKeys:nil ignoredKeys:ignoredKeys error:error];
}

- (NSMutableDictionary *)keyValuesWithKeys:(NSArray *)keys ignoredKeys:(NSArray *)ignoredKeys error:(NSError *__autoreleasing *)error
{
    // 如果自己不是模型类
    if ([MJFoundation isClassFromFoundation:[self class]]) return (NSMutableDictionary *)self;
    
    id keyValues = [NSMutableDictionary dictionary];
    
    Class aClass = [self class];
    NSArray *allowedPropertyNames = [aClass totalAllowedPropertyNames];
    if ([self isKindOfClass:[NSManagedObject class]] && allowedPropertyNames.count == 0) {
        NSManagedObject *object = self;
        allowedPropertyNames = [aClass defaultAllowPropertyNamesWithContext:object.managedObjectContext error:error];
        //加入缓存
        [aClass setupAllowedPropertyNames:^NSArray *{
            return allowedPropertyNames;
        }];
    }
    NSArray *ignoredPropertyNames = [aClass totalIgnoredPropertyNames];
    
    [aClass enumerateProperties:^(MJProperty *property, BOOL *stop) {
        @try {
            // 0.检测是否被忽略
            if (allowedPropertyNames.count && ![allowedPropertyNames containsObject:property.name]) return;
            if ([ignoredPropertyNames containsObject:property.name]) return;
            if (keys.count && ![keys containsObject:property.name]) return;
            if ([ignoredKeys containsObject:property.name]) return;
            
            // 1.取出属性值
            id value = [property valueForObject:self];
            if (!value) return;
            
            // 2.如果是模型属性
            MJPropertyType *type = property.type;
            Class typeClass = type.typeClass;
            if (!type.isFromFoundation && typeClass) {
                if ([typeClass isSubclassOfClass:[NSManagedObject class]] && [self isKindOfClass:[NSManagedObject class]]) {
                    //core data对象关联另一个core data对象，可能存在inverse关系，需要过滤，否则造成循环调用
                    NSManagedObject *object = self;
                    NSManagedObjectContext *context = object.managedObjectContext;
                    NSEntityDescription *entityDescription = [NSEntityDescription entityForName:NSStringFromClass([self class]) inManagedObjectContext:context];
                    NSRelationshipDescription *relationshipDescription = entityDescription.relationshipsByName[property.name];
                    NSString *inverseRelationName = relationshipDescription.inverseRelationship.name;
                    NSArray *ignoreKeys;
                    if (inverseRelationName) {
                        ignoreKeys = @[inverseRelationName];
                    }
                    value = [value keyValuesWithIgnoredKeys:ignoreKeys];
                } else {
                    value = [value keyValues];
                }
            } else if ([MJFoundation isCollectionClass:[value class]]) {
                // 3.处理数组里面有模型的情况
                value = [NSObject keyValuesArrayWithObjectArray:value];
            } else if (typeClass == [NSURL class]) {
                value = [value absoluteString];
            }
            
            // 4.赋值
            if ([aClass isReferenceReplacedKeyWhenCreatingKeyValues]) {
                NSArray *propertyKeys = [[property propertyKeysForClass:aClass] firstObject];
                NSUInteger keyCount = propertyKeys.count;
                // 创建字典
                __block id innerContainer = keyValues;
                [propertyKeys enumerateObjectsUsingBlock:^(MJPropertyKey *propertyKey, NSUInteger idx, BOOL *stop) {
                    // 下一个属性
                    MJPropertyKey *nextPropertyKey = nil;
                    if (idx != keyCount - 1) {
                        nextPropertyKey = propertyKeys[idx + 1];
                    }
                    
                    if (nextPropertyKey) { // 不是最后一个key
                        // 当前propertyKey对应的字典或者数组
                        id tempInnerContainer = [propertyKey valueInObject:innerContainer];
                        if (tempInnerContainer == nil || [tempInnerContainer isKindOfClass:[NSNull class]]) {
                            if (nextPropertyKey.type == MJPropertyKeyTypeDictionary) {
                                tempInnerContainer = [NSMutableDictionary dictionary];
                            } else {
                                tempInnerContainer = [NSMutableArray array];
                            }
                            if (propertyKey.type == MJPropertyKeyTypeDictionary) {
                                innerContainer[propertyKey.name] = tempInnerContainer;
                            } else {
                                innerContainer[propertyKey.name.intValue] = tempInnerContainer;
                            }
                        }
                        
                        if ([tempInnerContainer isKindOfClass:[NSMutableArray class]]) {
                            int index = nextPropertyKey.name.intValue;
                            while ([tempInnerContainer count] < index + 1) {
                                [tempInnerContainer addObject:[NSNull null]];
                            }
                        }
                        
                        innerContainer = tempInnerContainer;
                    } else { // 最后一个key
                        if (propertyKey.type == MJPropertyKeyTypeDictionary) {
                            innerContainer[propertyKey.name] = value;
                        } else {
                            innerContainer[propertyKey.name.intValue] = value;
                        }
                    }
                }];
            } else {
                keyValues[property.name] = value;
            }
        } @catch (NSException *exception) {
            MJExtensionBuildError(error, exception.reason);
            NSLog(@"%@", exception);
        }
    }];
    
    // 去除系统自动增加的元素
    if ([keyValues isKindOfClass:[NSMutableDictionary class]]) {
        [keyValues removeObjectsForKeys:@[@"superclass", @"debugDescription", @"description", @"hash"]];
    }
    
    // 转换完毕
    if ([self respondsToSelector:@selector(objectDidFinishConvertingToKeyValues)]) {
        [self objectDidFinishConvertingToKeyValues];
    }
    
    return keyValues;
}
#pragma mark - 模型数组 -> 字典数组

#pragma mark Array
+ (NSMutableArray *)keyValuesArrayWithObjectArray:(NSArray *)objectArray
{
    return [self keyValuesArrayWithObjectArray:objectArray error:nil];
}

+ (NSMutableArray *)keyValuesArrayWithObjectArray:(NSArray *)objectArray error:(NSError *__autoreleasing *)error
{
    return [self keyValuesArrayWithObjectArray:objectArray ignoredKeys:nil error:error];
}

+ (NSMutableArray *)keyValuesArrayWithObjectArray:(NSArray *)objectArray keys:(NSArray *)keys
{
    return [self keyValuesArrayWithObjectArray:objectArray keys:keys error:nil];
}

+ (NSMutableArray *)keyValuesArrayWithObjectArray:(NSArray *)objectArray ignoredKeys:(NSArray *)ignoredKeys
{
    return [self keyValuesArrayWithObjectArray:objectArray ignoredKeys:ignoredKeys error:nil];
}

+ (NSMutableArray *)keyValuesArrayWithObjectArray:(NSArray *)objectArray keys:(NSArray *)keys error:(NSError *__autoreleasing *)error
{
    return [self keyValuesArrayWithObjectArray:objectArray keys:keys ignoredKeys:nil error:error];
}

+ (NSMutableArray *)keyValuesArrayWithObjectArray:(NSArray *)objectArray ignoredKeys:(NSArray *)ignoredKeys error:(NSError *__autoreleasing *)error
{
    return [self keyValuesArrayWithObjectArray:objectArray keys:nil ignoredKeys:ignoredKeys error:error];
}

+ (NSMutableArray *)keyValuesArrayWithObjectArray:(NSArray *)objectArray keys:(NSArray *)keys ignoredKeys:(NSArray *)ignoredKeys error:(NSError *__autoreleasing *)error
{
    return [self keyValuesArrayWithObjectCollection:objectArray keys:keys ignoredKeys:ignoredKeys error:error];
}

#pragma mark Set

+ (NSMutableArray *)keyValuesArrayWithObjectSet:(NSSet *)objectSet {
    return [self keyValuesArrayWithObjectSet:objectSet error:NULL];
}
+ (NSMutableArray *)keyValuesArrayWithObjectSet:(NSSet *)objectSet error:(NSError **)error {
    return [self keyValuesArrayWithObjectCollection:objectSet keys:nil ignoredKeys:nil error:error];
}
+ (NSMutableArray *)keyValuesArrayWithObjectSet:(NSSet *)objectSet keys:(NSArray *)keys {
    return [self keyValuesArrayWithObjectSet:objectSet keys:keys error:NULL];
}
+ (NSMutableArray *)keyValuesArrayWithObjectSet:(NSSet *)objectSet keys:(NSArray *)keys error:(NSError **)error {
    return [self keyValuesArrayWithObjectCollection:objectSet keys:keys ignoredKeys:nil error:error];
}
+ (NSMutableArray *)keyValuesArrayWithObjectSet:(NSSet *)objectSet ignoredKeys:(NSArray *)ignoredKeys {
    return [self keyValuesArrayWithObjectSet:objectSet ignoredKeys:ignoredKeys error:NULL];
}
+ (NSMutableArray *)keyValuesArrayWithObjectSet:(NSSet *)objectSet ignoredKeys:(NSArray *)ignoredKeys error:(NSError **)error {
    return [self keyValuesArrayWithObjectCollection:objectSet keys:nil ignoredKeys:ignoredKeys error:error];
}

#pragma mark OrderSet

+ (NSMutableArray *)keyValuesArrayWithObjectOrderedSet:(NSOrderedSet *)objectOrderedSet {
    return [self keyValuesArrayWithObjectOrderedSet:objectOrderedSet error:NULL];
}
+ (NSMutableArray *)keyValuesArrayWithObjectOrderedSet:(NSOrderedSet *)objectOrderedSet error:(NSError **)error {
    return [self keyValuesArrayWithObjectCollection:objectOrderedSet keys:nil ignoredKeys:nil error:error];
}
+ (NSMutableArray *)keyValuesArrayWithObjectOrderedSet:(NSOrderedSet *)objectOrderedSet keys:(NSArray *)keys {
    return [self keyValuesArrayWithObjectOrderedSet:objectOrderedSet keys:keys error:NULL];
}
+ (NSMutableArray *)keyValuesArrayWithObjectOrderedSet:(NSOrderedSet *)objectOrderedSet keys:(NSArray *)keys error:(NSError **)error {
    return [self keyValuesArrayWithObjectCollection:objectOrderedSet keys:keys ignoredKeys:nil error:error];
}
+ (NSMutableArray *)keyValuesArrayWithObjectOrderedSet:(NSOrderedSet *)objectOrderedSet ignoredKeys:(NSArray *)ignoredKeys {
    return [self keyValuesArrayWithObjectOrderedSet:objectOrderedSet ignoredKeys:ignoredKeys error:NULL];
}
+ (NSMutableArray *)keyValuesArrayWithObjectOrderedSet:(NSOrderedSet *)objectOrderedSet ignoredKeys:(NSArray *)ignoredKeys error:(NSError **)error {
    return [self keyValuesArrayWithObjectCollection:objectOrderedSet keys:nil ignoredKeys:ignoredKeys error:error];
}

#pragma mark - 转换为JSON
- (NSData *)JSONData
{
    if ([self isKindOfClass:[NSString class]]) {
        return [((NSString *)self) dataUsingEncoding:NSUTF8StringEncoding];
    } else if ([self isKindOfClass:[NSData class]]) {
        return (NSData *)self;
    }
    
    return [NSJSONSerialization dataWithJSONObject:[self JSONObject] options:kNilOptions error:nil];
}

- (id)JSONObject
{
    if ([self isKindOfClass:[NSString class]]) {
        return [NSJSONSerialization JSONObjectWithData:[((NSString *)self) dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:nil];
    } else if ([self isKindOfClass:[NSData class]]) {
        return [NSJSONSerialization JSONObjectWithData:(NSData *)self options:kNilOptions error:nil];
    }
    
    return self.keyValues;
}

- (NSString *)JSONString
{
    if ([self isKindOfClass:[NSString class]]) {
        return (NSString *)self;
    } else if ([self isKindOfClass:[NSData class]]) {
        return [[NSString alloc] initWithData:(NSData *)self encoding:NSUTF8StringEncoding];
    }
    
    return [[NSString alloc] initWithData:[self JSONData] encoding:NSUTF8StringEncoding];
}

#pragma mark - 私有方法

+ (id)objectMutableCollection:(id)mutableCollection withKeyValuesArray:(id)keyValuesArray context:(NSManagedObjectContext *)context error:(NSError *__autoreleasing *)error {
    // 如果数组里面放的是NSString、NSNumber等数据
    if ([MJFoundation isClassFromFoundation:self]) {
        if ([mutableCollection isKindOfClass:[NSMutableSet class]]) {
            return [NSMutableSet setWithArray:keyValuesArray];
        } else if ([mutableCollection isKindOfClass:[NSMutableOrderedSet class]]) {
            return [NSMutableOrderedSet orderedSetWithArray:keyValuesArray];
        } else {
            return [NSMutableArray arrayWithArray:keyValuesArray];
        }
    }
    
    // 如果是JSON字符串
    keyValuesArray = [keyValuesArray JSONObject];
    
    // 1.判断真实性
    MJExtensionAssertError([keyValuesArray isKindOfClass:[NSArray class]], nil, error, @"keyValuesArray参数不是一个数组");
    
    // 2.遍历
    for (NSDictionary *keyValues in keyValuesArray) {
        if ([keyValues isKindOfClass:[NSArray class]]){
            [mutableCollection addObject:[self objectArrayWithKeyValuesArray:keyValues context:context error:error]];
        } else {
            id model = [self objectWithKeyValues:keyValues context:context error:error];
            if (model) [mutableCollection addObject:model];
        }
    }
    
    return mutableCollection;
}

+ (NSMutableArray *)keyValuesArrayWithObjectCollection:(id)objectCollection keys:(NSArray *)keys ignoredKeys:(NSArray *)ignoredKeys error:(NSError *__autoreleasing *)error
{
    // 0.判断真实性
    MJExtensionAssertError([MJFoundation isCollectionClass:[objectCollection class]], nil, error, @"objectArray参数不是一个容器");
    
    // 1.创建数组
    NSMutableArray *keyValuesArray = [NSMutableArray array];
    for (id object in objectCollection) {
        if (keys) {
            [keyValuesArray addObject:[object keyValuesWithKeys:keys error:error]];
        } else {
            [keyValuesArray addObject:[object keyValuesWithIgnoredKeys:ignoredKeys error:error]];
        }
    }
    return keyValuesArray;
}

/**
 *  对象初始化工厂方法，根据class生成对应的实例
 */
+ (NSObject *)generateDataWithKeyValue:(id)keyValues inContext:(NSManagedObjectContext *)context error:(NSError **)error {
    return [[self alloc] init];
}

@end

/**
 *  重写实例生成方法，core data对象先通过identityPropertyName查找是否包含有对应的数据，如果有，则生成该数据的实例进行更新，否则插入新数据
 */
@implementation NSManagedObject (MJKeyValue)

+ (NSObject *)generateDataWithKeyValue:(id)keyValues inContext:(NSManagedObjectContext *)context error:(NSError **)error {
    MJExtensionAssertError([keyValues isKindOfClass:[NSDictionary class]], nil, error, @"keyValue参数不是一个NSDictionary");
    MJExtensionAssertError(context != nil, nil, error, @"没有传递context");
    Class aClass = self;
    NSManagedObject *mappingObject;
    NSArray *identityProperyNames = [aClass totalIdentityPropertyNames];
    
    //TODO:这里的代码和setKeyValues:的代码有重复，后期需要优化
    //设置了唯一键值，则尝试去数据库中找到对应的数据
    if (identityProperyNames.count > 0) {
        NSMutableArray *predicateArray = [[NSMutableArray alloc] initWithCapacity:identityProperyNames.count];
        [aClass enumerateProperties:^(MJProperty *property, BOOL *stop) {
            if ([identityProperyNames containsObject:property.name]) {
                // 1.取出属性值
                id value;
                NSArray *propertyKeyses = [property propertyKeysForClass:aClass];
                for (NSArray *propertyKeys in propertyKeyses) {
                    value = keyValues;
                    for (MJPropertyKey *propertyKey in propertyKeys) {
                        value = [propertyKey valueInObject:value];
                    }
                    if (value) break;
                }
                
                // 2.值的过滤
                id newValue = [aClass getNewValueFromObject:self oldValue:value property:property];
                if (newValue) value = newValue;
                
                // 3.建立predicate
                if (value) {
                    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", property.name, value];
                    [predicateArray addObject:predicate];
                } else {
                    //unique key不在keyValues中，取消遍历，直接插入新数据
                    *stop = YES;
                }
            }
        }];
        
        // 4. 查询对象
        if (predicateArray.count == identityProperyNames.count) {
            NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass(self)];
            fetchRequest.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:predicateArray];
            fetchRequest.fetchLimit = 1;
            mappingObject = [context executeFetchRequest:fetchRequest error:error].firstObject;
            if (!error) {
                return nil;
            }
        }
    }
    
    if (!mappingObject) {
        mappingObject = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass(self) inManagedObjectContext:context];
    }
    
    return [mappingObject setKeyValues:keyValues context:context error:error];
}

+ (NSArray *)defaultAllowPropertyNamesWithContext:(NSManagedObjectContext *)context error:(NSError **)error {
    MJExtensionAssertError(context != nil, nil, error, @"传入的context为nil");
    NSEntityDescription *description = [NSEntityDescription entityForName:NSStringFromClass([self class]) inManagedObjectContext:context];
    return [[description propertiesByName].allKeys arrayByAddingObjectsFromArray:[description relationshipsByName].allKeys];
}
@end
