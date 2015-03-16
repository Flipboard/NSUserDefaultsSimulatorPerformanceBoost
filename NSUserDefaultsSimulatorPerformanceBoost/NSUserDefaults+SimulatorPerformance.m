//
//  NSUserDefaults+SimulatorPerformance.m
//  Flipboard
//
//  Created by Tim Johnsen on 1/21/15.
//  Copyright (c) 2015 Flipboard. All rights reserved.
//

#import "NSUserDefaults+SimulatorPerformance.h"

#if TARGET_IPHONE_SIMULATOR

#import <objc/runtime.h>

// If enabled, this flag causes the app to compare cached values to those looked up from the real copy of NSUserDefaults
#define TEST_CACHED_VALUES 0

void fl_swizzle(Class class, SEL originalSelector, SEL swizzledSelector)
{
    Method originalMethod = class_getInstanceMethod(class, originalSelector);
    Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
    
    BOOL didAddMethod = class_addMethod(class, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod));
    
    if (didAddMethod) {
        class_replaceMethod(class, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}

@implementation NSUserDefaults (SimulatorPerformance)

#pragma mark - NSObject

+ (void)load
{
    [self trySetupSimulatorPerformanceImprovements];
}

#pragma mark - Setup

+ (void)trySetupSimulatorPerformanceImprovements
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSLog(@"%@ is being swizzled to use a cache in the simulator. If you experience %@-related funkiness try disabling the %@ method.", NSStringFromClass(self), NSStringFromClass(self), NSStringFromSelector(_cmd));
        
        fl_swizzle([self class], @selector(registerDefaults:), @selector(fl_registerDefaults:));
        
        fl_swizzle([self class], @selector(objectForKey:), @selector(fl_objectForKey:));
        fl_swizzle([self class], @selector(setObject:forKey:), @selector(fl_setObject:forKey:));
        fl_swizzle([self class], @selector(removeObjectForKey:), @selector(fl_removeObjectForKey:));
        
        // All public getters need to be overridden because their internal implementation doesn't funnel through -objectForKey:, they route to dedicated CFPreferences getters. In order for the cache to work all lookups need to be routed to our dictionary.
        
        fl_swizzle([self class], @selector(stringForKey:), @selector(fl_stringForKey:));
        fl_swizzle([self class], @selector(arrayForKey:), @selector(fl_arrayForKey:));
        fl_swizzle([self class], @selector(dictionaryForKey:), @selector(fl_dictionaryForKey:));
        fl_swizzle([self class], @selector(dataForKey:), @selector(fl_dataForKey:));
        fl_swizzle([self class], @selector(stringArrayForKey:), @selector(fl_stringArrayForKey:));
        fl_swizzle([self class], @selector(integerForKey:), @selector(fl_integerForKey:));
        fl_swizzle([self class], @selector(floatForKey:), @selector(fl_floatForKey:));
        fl_swizzle([self class], @selector(doubleForKey:), @selector(fl_doubleForKey:));
        fl_swizzle([self class], @selector(boolForKey:), @selector(fl_boolForKey:));
        fl_swizzle([self class], @selector(URLForKey:), @selector(fl_URLForKey:));
        
        // All public setters need to be overridden because otherwise our cached in-memory values can become inconsistent with what's on disk
        
        fl_swizzle([self class], @selector(setInteger:forKey:), @selector(fl_setInteger:forKey:));
        fl_swizzle([self class], @selector(setFloat:forKey:), @selector(fl_setFloat:forKey:));
        fl_swizzle([self class], @selector(setDouble:forKey:), @selector(fl_setDouble:forKey:));
        fl_swizzle([self class], @selector(setBool:forKey:), @selector(fl_setBool:forKey:));
        fl_swizzle([self class], @selector(setURL:forKey:), @selector(fl_setURL:forKey:));
    });
}

#pragma mark - Helpers

/// Keeps one NSMutableDictionary cache per instance of NSUserDefaults
- (NSMutableDictionary *)cachedDefaultsValues
{
    static NSMutableDictionary *cachedDefaultsValuesForUserDefaultsInstances = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cachedDefaultsValuesForUserDefaultsInstances = [[NSMutableDictionary alloc] init];
    });
    
    id<NSCopying> key = [NSValue valueWithNonretainedObject:self];
    NSMutableDictionary *cachedDefaultsValues = [cachedDefaultsValuesForUserDefaultsInstances objectForKey:key];
    if (!cachedDefaultsValues) {
        cachedDefaultsValues = [[NSMutableDictionary alloc] init];
        [cachedDefaultsValuesForUserDefaultsInstances setObject:cachedDefaultsValues forKey:key];
    }
    
    return cachedDefaultsValues;
}

- (dispatch_queue_t)cachedDefaultsQueue
{
    static dispatch_queue_t cachedDefaultsQueue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cachedDefaultsQueue = dispatch_queue_create("com.flipboard.NSUserDefaultsSimulatorPerformanceBoost", DISPATCH_QUEUE_CONCURRENT);
    });
    return cachedDefaultsQueue;
}

#pragma mark - Generics

- (id)fl_objectForKey:(NSString *)key
{
    __block id object = nil;
    dispatch_sync([self cachedDefaultsQueue], ^{
        NSMutableDictionary *cachedDefaultsValues = [self cachedDefaultsValues];
        object = [cachedDefaultsValues objectForKey:key];
        if (!object) {
            object = [self fl_objectForKey:key];
            if (object) {
                [cachedDefaultsValues setObject:object forKey:key];
            } else {
                [cachedDefaultsValues setObject:[NSNull null] forKey:key];
            }
        } else if (object == [NSNull null]) {
            object = nil;
        }
        
#if TEST_CACHED_VALUES
        id conventionalObject = [self fl_objectForKey:key];
        FLAssert(FLIsEqual(object, conventionalObject), @"OBJECTS UNEQUAL FOR KEY %@ - %@, %@", key, object, conventionalObject);
#endif
    });
    
    return object;
}

- (void)fl_setObject:(id)object forKey:(NSString *)key
{
    [self fl_setObject:object forKey:key writeThrough:YES];
}

/// @param writeThrough Indicates whether the provided value should be copied through to the real copy of NSUserDefaults
- (void)fl_setObject:(id)object forKey:(NSString *)key writeThrough:(BOOL)writeThrough
{
    void (^setObjectBlock)(void) = ^ {
        NSMutableDictionary *cachedDefaultsValues = [self cachedDefaultsValues];
        if (object) {
            [cachedDefaultsValues setObject:object forKey:key];
        } else {
            // Remove the value from our cache so it's looked up next time
            // This is important, if we set it to NSNull rather than nil and there's a registered standard user default our values will become inconsistent
            [cachedDefaultsValues removeObjectForKey:key];
        }
    };
    
    if (writeThrough) {
        // If we're writing through to the underlying instance of NSUserDefaults lock around the two writes
        dispatch_barrier_async([self cachedDefaultsQueue], ^{
            setObjectBlock();
            
            // Write through to the actual copy of NSUserDefaults
            [self fl_setObject:object forKey:key];
        });
    } else {
        // Otherwise it's implied that a client will perform the locking and write through to the underling NSUserDefaults instance, don't lock here
        setObjectBlock();
    }
}

- (void)fl_removeObjectForKey:(NSString *)key
{
    [self setObject:nil forKey:key];
}

#pragma mark - Specific Type Getters

- (NSString *)fl_stringForKey:(NSString *)key
{
    NSString *value = nil;
    id object = [self objectForKey:key];
    if ([object isKindOfClass:[NSString class]]) {
        value = (NSString *)object;
    }
    return value;
}

- (NSArray *)fl_arrayForKey:(NSString *)key
{
    NSArray *value = nil;
    id object = [self objectForKey:key];
    if ([object isKindOfClass:[NSArray class]]) {
        value = (NSArray *)object;
    }
    return value;
}

- (NSDictionary *)fl_dictionaryForKey:(NSString *)key
{
    NSDictionary *value = nil;
    id object = [self objectForKey:key];
    if ([object isKindOfClass:[NSDictionary class]]) {
        value = (NSDictionary *)object;
    }
    return value;
}

- (NSData *)fl_dataForKey:(NSString *)key
{
    NSData *value = nil;
    id object = [self objectForKey:key];
    if ([object isKindOfClass:[NSData class]]) {
        value = (NSData *)object;
    }
    return value;
}

- (NSArray *)fl_stringArrayForKey:(NSString *)key
{
    NSArray *array = [self arrayForKey:key];
    for (id object in array) {
        // Don't permit values other than strings to be contained within the array
        if (![object isKindOfClass:[NSString class]]) {
            array = nil;
            break;
        }
    }
    return array;
}

- (NSInteger)fl_integerForKey:(NSString *)key
{
    NSInteger value = NO;
    id object = [self objectForKey:key];
    if ([object isKindOfClass:[NSNumber class]]) {
        value = [object integerValue];
    }
    return value;
}

- (float)fl_floatForKey:(NSString *)key
{
    float value = NO;
    id object = [self objectForKey:key];
    if ([object isKindOfClass:[NSNumber class]]) {
        value = [object floatValue];
    }
    return value;
}

- (double)fl_doubleForKey:(NSString *)key
{
    double value = NO;
    id object = [self objectForKey:key];
    if ([object isKindOfClass:[NSNumber class]]) {
        value = [object doubleValue];
    }
    return value;
}

- (BOOL)fl_boolForKey:(NSString *)key
{
    BOOL value = NO;
    id object = [self objectForKey:key];
    if ([object isKindOfClass:[NSNumber class]]) {
        value = [object boolValue];
    }
    return value;
}

- (NSURL *)fl_URLForKey:(NSString *)key
{
    NSURL *value = nil;
    id object = [self objectForKey:key];
    if ([object isKindOfClass:[NSURL class]]) {
        value = (NSURL *)object;
    }
    return value;
}

#pragma mark - Specific Type Setters

- (void)fl_setInteger:(NSInteger)value forKey:(NSString *)defaultName
{
    dispatch_barrier_async([self cachedDefaultsQueue], ^{
        [self fl_setObject:[NSNumber numberWithInteger:value] forKey:defaultName writeThrough:NO];
        [self fl_setInteger:value forKey:defaultName];
    });
}

- (void)fl_setFloat:(float)value forKey:(NSString *)defaultName
{
    dispatch_barrier_async([self cachedDefaultsQueue], ^{
        [self fl_setObject:[NSNumber numberWithFloat:value] forKey:defaultName writeThrough:NO];
        [self fl_setFloat:value forKey:defaultName];
    });
}

- (void)fl_setDouble:(double)value forKey:(NSString *)defaultName
{
    dispatch_barrier_async([self cachedDefaultsQueue], ^{
        [self fl_setObject:[NSNumber numberWithDouble:value] forKey:defaultName writeThrough:NO];
        [self fl_setDouble:value forKey:defaultName];
    });
}

- (void)fl_setBool:(BOOL)value forKey:(NSString *)defaultName
{
    dispatch_barrier_async([self cachedDefaultsQueue], ^{
        [self fl_setObject:[NSNumber numberWithBool:value] forKey:defaultName writeThrough:NO];
        [self fl_setBool:value forKey:defaultName];
    });
}

- (void)fl_setURL:(NSURL *)url forKey:(NSString *)defaultName
{
    dispatch_barrier_async([self cachedDefaultsQueue], ^{
        [self fl_setObject:url forKey:defaultName writeThrough:NO];
        [self fl_setURL:url forKey:defaultName];
    });
}

#pragma mark - Defaults Registration

- (void)fl_registerDefaults:(NSDictionary *)registrationDictionary
{
    dispatch_barrier_async([self cachedDefaultsQueue], ^{
        // Discard cached values so they're looked up again later
        // Otherwise the cached values can be inconsistent with those in NSUserDefaults if the defaults have changes
        [[self cachedDefaultsValues] removeAllObjects];
        [self fl_registerDefaults:registrationDictionary];
    });
}

@end

#endif
