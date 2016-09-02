//
//  ViewController.m
//  STKVODemo
//
//  Created by MacBook on 16/8/24.
//  Copyright © 2016年 Macbook. All rights reserved.
//

#import "ViewController.h"
#import "NSObject+STKVO.h"



@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIImageView *imageView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.imageView st_addObserver:self forKey:NSStringFromSelector(@selector(image)) selector:@selector(imageDidChanged)];
}

- (void)imageDidChanged
{
    NSLog(@"stupid demo finally hit there!");
}

- (IBAction)buttonClicked:(UIButton *)button {
    switch (button.tag) {
        case 1:
            [self.imageView setImage:[UIImage imageNamed:@"1"]];
            break;
            
        case 2:
            [self.imageView setImage:[UIImage imageNamed:@"2"]];
            break;
            
        case 3:
            [self.imageView setImage:[UIImage imageNamed:@"3"]];
            break;
            
        case 4:
            [self.imageView setImage:[UIImage imageNamed:@"4"]];
            break;
            
        default:
            break;
    }
}

@end
