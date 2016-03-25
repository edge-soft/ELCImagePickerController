//
//  AssetCell.h
//
//  Created by ELC on 2/15/11.
//  Copyright 2011 ELC Technologies. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ELCAsset.h"

@interface ELCAssetCell : UITableViewCell

@property (nonatomic, weak) id<ELCAssetDelegate> parent;
@property (nonatomic, assign) BOOL alignmentLeft;
@property (nonatomic, assign) CGFloat itemPadding;
@property (nonatomic, assign) NSInteger numberOfColumns;

- (void)setAssets:(NSArray *)assets;

@end
