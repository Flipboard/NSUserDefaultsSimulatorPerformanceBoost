//
//  ViewController.m
//  NSUserDefaultsSimulatorPerformanceBoost
//
//  Created by Tim Johnsen on 3/16/15.
//  Copyright (c) 2015 flipboard. All rights reserved.
//

#import "ViewController.h"

@interface NSUserDefaults (Private)

- (id)fl_objectForKey:(NSString *)key;

@end

@interface ViewController ()

@property (nonatomic, strong) IBOutlet UISlider *slider;
@property (nonatomic, strong) IBOutlet UILabel *sliderValueLabel;
@property (nonatomic, strong) IBOutlet UITextView *logTextView;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self updateSliderLabel];
    
    if (![NSUserDefaults instancesRespondToSelector:@selector(fl_objectForKey:)]) {
        [[[UIAlertView alloc] initWithTitle:@"Warning!" message:@"NSUserDefaults performance improvements are not currently enabled! Testing NSUserDefaults performance in this build will be inaccurate!" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
    }
}

- (NSString *)randomKey
{
    return [NSString stringWithFormat:@"%lu", (unsigned long)arc4random_uniform(self.slider.value)];
}

- (id)randomObject
{
    id randomObject = nil;
    switch (arc4random_uniform(4)) {
        case 0:
            randomObject = [NSString stringWithFormat:@"%lu", (unsigned long)arc4random()];
            break;
        case 1:
            randomObject = @(arc4random());
            break;
        case 2:
            randomObject = @{[NSString stringWithFormat:@"%lu", (unsigned long)arc4random()] : @(arc4random())};
            break;
        case 3:
            randomObject = @[@(arc4random()), @(arc4random())];
            break;
        default:
            break;
    }
    
    return randomObject;
}

- (IBAction)writeButtonTapped:(id)sender
{
    NSUInteger writeCount = self.slider.value;
    [self log:[NSString stringWithFormat:@"Writing %lu values to NSUserDefaults", writeCount]];
    CFTimeInterval startTime = CACurrentMediaTime();
    for (NSUInteger i = 0; i < writeCount; i++) {
        [[NSUserDefaults standardUserDefaults] setObject:[self randomObject] forKey:[self randomKey]];
    }
    CFTimeInterval duration = CACurrentMediaTime() - startTime;
    [self log:[NSString stringWithFormat:@"Finished writing %lu values to NSUserDefaults, took %f seconds", writeCount, duration]];
}

- (IBAction)readSlowButtonTapped:(id)sender
{
    NSUInteger readCount = self.slider.value;
    [self log:[NSString stringWithFormat:@"Reading %lu values from NSUserDefaults (slow)", readCount]];
    CFTimeInterval startTime = CACurrentMediaTime();
    for (NSUInteger i = 0; i < readCount; i++) {
        id object = [[NSUserDefaults standardUserDefaults] fl_objectForKey:[self randomKey]];
#pragma unused(object)
    }
    CFTimeInterval duration = CACurrentMediaTime() - startTime;
    [self log:[NSString stringWithFormat:@"Finished reading %lu values from NSUserDefaults (slow), took %f seconds", readCount, duration]];
}

- (IBAction)readFastButtonTapped:(id)sender
{
    NSUInteger readCount = self.slider.value;
    [self log:[NSString stringWithFormat:@"Reading %lu values from NSUserDefaults (fast)", readCount]];
    CFTimeInterval startTime = CACurrentMediaTime();
    for (NSUInteger i = 0; i < readCount; i++) {
        id object = [[NSUserDefaults standardUserDefaults] objectForKey:[self randomKey]];
#pragma unused(object)
    }
    CFTimeInterval duration = CACurrentMediaTime() - startTime;
    [self log:[NSString stringWithFormat:@"Finished reading %lu values from NSUserDefaults (fast), took %f seconds", readCount, duration]];
}

- (IBAction)sliderValueChanged:(id)sender
{
    [self updateSliderLabel];
}

- (void)updateSliderLabel
{
    self.sliderValueLabel.text = [NSString stringWithFormat:@"%0.0f", self.slider.value];
}

- (void)log:(NSString *)logString
{
    NSLog(@"%@", logString);
    self.logTextView.text = [self.logTextView.text stringByAppendingFormat:@"\n%@", logString];
}

@end
