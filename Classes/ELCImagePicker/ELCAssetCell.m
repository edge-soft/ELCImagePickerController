//
//  AssetCell.m
//
//  Created by ELC on 2/15/11.
//  Copyright 2011 ELC Technologies. All rights reserved.
//

#import "ELCAssetCell.h"
#import "ELCAsset.h"
#import "ELCConsole.h"
#import "ELCOverlayImageView.h"
#import "ELCConstants.h"
#import <Photos/Photos.h>

@interface ELCAssetCell ()

@property (nonatomic, strong) NSArray *rowAssets;
@property (nonatomic, strong) NSMutableArray *imageViewArray;
@property (nonatomic, strong) NSMutableArray *overlayViewArray;

@property (strong) PHCachingImageManager *imageManager;

@property (nonatomic) CGFloat itemDimension;

@end

@implementation ELCAssetCell

//Using auto synthesizers

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
	if (self) {
        self.numberOfColumns = 4;
        self.itemDimension = 75;
        self.itemPadding = 4.0f;
        
        UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(cellTapped:)];
        [self addGestureRecognizer:tapRecognizer];
        
        NSMutableArray *mutableArray = [[NSMutableArray alloc] initWithCapacity:4];
        self.imageViewArray = mutableArray;
        
        NSMutableArray *overlayArray = [[NSMutableArray alloc] initWithCapacity:4];
        self.overlayViewArray = overlayArray;
        
        self.alignmentLeft = YES;
        self.imageManager = [[PHCachingImageManager alloc] init];
	}
	return self;
}

- (void)setAssets:(NSArray *)assets
{
    self.rowAssets = assets;
	for (UIImageView *view in _imageViewArray) {
        [view removeFromSuperview];
	}
    for (ELCOverlayImageView *view in _overlayViewArray) {
        [view removeFromSuperview];
	}
    //set up a pointer here so we don't keep calling [UIImage imageNamed:] if creating overlays
    
    if(!IS_IOS8){
        UIImage *overlayImage = nil;
        for (int i = 0; i < [_rowAssets count]; ++i) {

            ELCAsset *asset = [_rowAssets objectAtIndex:i];

            if (i < [_imageViewArray count]) {
                UIImageView *imageView = [_imageViewArray objectAtIndex:i];
                imageView.image = [UIImage imageWithCGImage:((ALAsset*)asset.asset).thumbnail];
            } else {
                UIImageView *imageView = [[UIImageView alloc] initWithImage:[UIImage imageWithCGImage:((ALAsset*)asset.asset).thumbnail]];
                [_imageViewArray addObject:imageView];
            }
            
            if (i < [_overlayViewArray count]) {
                ELCOverlayImageView *overlayView = [_overlayViewArray objectAtIndex:i];
                overlayView.hidden = asset.selected ? NO : YES;
                overlayView.labIndex.text = [NSString stringWithFormat:@"%d", asset.index + 1];
            } else {
                if (overlayImage == nil) {
                    overlayImage = [UIImage imageNamed:@"Overlay.png"];
                }
                ELCOverlayImageView *overlayView = [[ELCOverlayImageView alloc] initWithImage:overlayImage];
                [_overlayViewArray addObject:overlayView];
                overlayView.hidden = asset.selected ? NO : YES;
                overlayView.labIndex.text = [NSString stringWithFormat:@"%d", asset.index + 1];
            }
        }
    } else {
   
        UIImage *overlayImage = nil;
        for (int i = 0; i < [_rowAssets count]; ++i) {
            
            ELCAsset *asset = [_rowAssets objectAtIndex:i];
            
            PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
            
            // Download from cloud if necessary
            // Need to make NO for existing images.
            options.networkAccessAllowed = YES;
            options.progressHandler = ^(double progress, NSError *error, BOOL *stop, NSDictionary *info) {
                
            };
            
            if (i < [_imageViewArray count]) {
                UIImageView *imageView = [_imageViewArray objectAtIndex:i];
                PHAsset *phAsset = (PHAsset *)asset.asset;
                [self.imageManager requestImageForAsset:phAsset targetSize:CGSizeMake(70, 70) contentMode:PHImageContentModeAspectFill options:options resultHandler:^(UIImage * result, NSDictionary * info) {
                    imageView.image = result;
                }];
                
            } else {
                UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 70, 70)];
                PHAsset *phAsset = (PHAsset *)asset.asset;
                [self.imageManager requestImageForAsset:phAsset targetSize:CGSizeMake(70, 70) contentMode:PHImageContentModeAspectFill options:options resultHandler:^(UIImage * result, NSDictionary * info) {
                    imageView.image = result;
                }];
                
                [_imageViewArray addObject:imageView];
            }
            
            if (i < [_overlayViewArray count]) {
                ELCOverlayImageView *overlayView = [_overlayViewArray objectAtIndex:i];
                overlayView.hidden = asset.selected ? NO : YES;
                overlayView.labIndex.text = [NSString stringWithFormat:@"%d", asset.index + 1];
            } else {
                if (overlayImage == nil) {
                    overlayImage = [UIImage imageNamed:@"Overlay.png"];
                }
                ELCOverlayImageView *overlayView = [[ELCOverlayImageView alloc] initWithImage:overlayImage];
                [_overlayViewArray addObject:overlayView];
                overlayView.hidden = asset.selected ? NO : YES;
                overlayView.labIndex.text = [NSString stringWithFormat:@"%d", asset.index + 1];
            }
        }
    
    }
}

- (void)cellTapped:(UITapGestureRecognizer *)tapRecognizer
{
    CGPoint point = [tapRecognizer locationInView:self];
    int c = (int32_t)self.rowAssets.count;
    CGFloat totalWidth = c * self.itemDimension + (c - 1) * self.itemPadding;
    CGFloat startX;
    
    if (self.alignmentLeft) {
        startX = self.itemPadding;
    }else {
        startX = (self.bounds.size.width - totalWidth) / 2;
    }
    
	CGRect frame = CGRectMake(startX, self.bounds.size.height/2 - self.itemDimension/2, self.itemDimension, self.itemDimension);
	
	for (int i = 0; i < [_rowAssets count]; ++i) {
        if (CGRectContainsPoint(frame, point)) {
            ELCAsset *asset = [_rowAssets objectAtIndex:i];
            
            //If selection reached maximum limit then just can deselect only
            if (!asset.selected && [_parent respondsToSelector:@selector(shouldSelectAsset:)])
            {
                if (![_parent shouldSelectAsset:nil])
                    return;
            }
            
            asset.selected = !asset.selected;
            ELCOverlayImageView *overlayView = [_overlayViewArray objectAtIndex:i];
            overlayView.hidden = !asset.selected;
            if (asset.selected) {
                asset.index = [[ELCConsole mainConsole] numOfSelectedElements];
                [overlayView setIndex:asset.index+1];
                [[ELCConsole mainConsole] addIndex:asset.index];
            }
            else
            {
                int lastElement = [[ELCConsole mainConsole] numOfSelectedElements] - 1;
                [[ELCConsole mainConsole] removeIndex:lastElement];
            }
            break;
        }
        frame.origin.x = frame.origin.x + frame.size.width + self.itemPadding;
    }
}

- (void)layoutSubviews
{
    self.itemDimension = (self.bounds.size.width - (self.numberOfColumns +1) * self.itemPadding) / self.numberOfColumns;
    int c = (int32_t)self.rowAssets.count;
    CGFloat totalWidth = c * self.itemDimension + (c - 1) * self.itemPadding;
    CGFloat startX;
    
    if (self.alignmentLeft) {
        startX = self.itemPadding;
    }else {
        startX = (self.bounds.size.width - totalWidth) / 2;
    }
    
	CGRect frame = CGRectMake(startX, self.itemPadding, self.itemDimension, self.itemDimension);
	
	for (int i = 0; i < [_rowAssets count]; ++i) {
		UIImageView *imageView = [_imageViewArray objectAtIndex:i];
		[imageView setFrame:frame];
		[self addSubview:imageView];
        
        ELCOverlayImageView *overlayView = [_overlayViewArray objectAtIndex:i];
        [overlayView setFrame:frame];
        [self addSubview:overlayView];
		
		frame.origin.x = frame.origin.x + frame.size.width + self.itemPadding;
	}
}


@end
