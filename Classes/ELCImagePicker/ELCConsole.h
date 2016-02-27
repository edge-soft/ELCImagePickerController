//
//  ELCConsole.h
//  ELCImagePickerDemo
//
//  Created by Seamus on 14-7-11.
//  Copyright (c) 2014年 ELC Technologies. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ELCConsole : NSObject
{
    NSMutableArray *myIndex;
}
@property (nonatomic,assign) BOOL onOrder;

@property (nonatomic, assign) BOOL enableToolbar;
@property (nonatomic, strong) UIColor *toolbarTintColor;
@property (nonatomic, strong) UIColor *toolbarBarTintColor;
@property (nonatomic, strong) UIImage *toolbarBackgroundImage;
@property (nonatomic, assign) UIBarStyle toolbarStyle;

+ (ELCConsole *)mainConsole;
- (void)addIndex:(int)index;
- (void)removeIndex:(int)index;
- (int)currIndex;
- (int)numOfSelectedElements;
- (void)removeAllIndex;
@end
