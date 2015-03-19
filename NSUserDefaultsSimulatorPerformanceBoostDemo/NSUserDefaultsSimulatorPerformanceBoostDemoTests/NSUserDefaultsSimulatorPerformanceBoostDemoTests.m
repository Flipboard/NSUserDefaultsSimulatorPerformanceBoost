//
//  NSUserDefaultsSimulatorPerformanceBoostDemoTests.m
//  NSUserDefaultsSimulatorPerformanceBoostDemoTests
//
//  Created by Tim Johnsen on 3/16/15.
//  Copyright (c) 2015 flipboard. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>

@interface NSUserDefaults (Private)

- (id)fl_objectForKey:(NSString *)key;

@end

@interface NSUserDefaultsSimulatorPerformanceBoostDemoTests : XCTestCase

@end

@implementation NSUserDefaultsSimulatorPerformanceBoostDemoTests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testSetAndRetrieveObject
{
    NSString *const key = [[NSUUID UUID] UUIDString];
    id object = NSStringFromSelector(_cmd);
    
    // Set
    [[NSUserDefaults standardUserDefaults] setObject:object forKey:key];
    
    // Retrieve
    id result = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    
    // Retrieve underlying object
    id underlyingResult = [[NSUserDefaults standardUserDefaults] fl_objectForKey:key];
    
    XCTAssertEqualObjects(object, result, @"Input and output results inconsistent.");
    XCTAssertEqualObjects(result, underlyingResult, @"Output result inconsistent with actual value stored in NSUserDefaults.");
}

- (void)testSetAndRemoveObject
{
    NSString *const key = [[NSUUID UUID] UUIDString];
    id object = NSStringFromSelector(_cmd);
    
    // Set
    [[NSUserDefaults standardUserDefaults] setObject:object forKey:key];
    
    // Remove
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
    
    // Retrieve
    id result = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    
    // Retrieve underlying object
    id underlyingResult = [[NSUserDefaults standardUserDefaults] fl_objectForKey:key];
    
    XCTAssertNil(result, @"Input and output results inconsistent.");
    XCTAssertNil(underlyingResult, @"Output result inconsistent with actual value stored in NSUserDefaults.");
}

- (void)testRegisteredDefaults
{
    // register
    // check value == registered value
}

- (void)testRegisteredDefaultsWithOverriddenValue
{
    // register
    // set object on top
    // check value == overridden value
}

- (void)testRegisteredDefualtsWithRemovedValue
{
    // register
    // set object on top
    // remove object on top
    // check value == registered value
}

// TODO: Primative types
// TODO: Differing instances

@end
