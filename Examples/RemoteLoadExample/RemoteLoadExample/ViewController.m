//
//  ViewController.m
//  RemoteLoadExample
//
//  Created by Craig on 9/5/12.
//  Copyright (c) 2012 Craig. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

@synthesize output;

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - IBACTION

- (IBAction)loadView:(id)sender {
    NSLog(@"Tapped");
}


@end
