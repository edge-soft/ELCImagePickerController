//
//  ELCImagePickerDemoViewController.m
//  ELCImagePickerDemo
//
//  Created by ELC on 9/9/10.
//  Copyright 2010 ELC Technologies. All rights reserved.
//

#import "ELCImagePickerDemoAppDelegate.h"
#import "ELCImagePickerDemoViewController.h"
#import <MobileCoreServices/UTCoreTypes.h>
#import <Photos/Photos.h>
#import "ELCConstants.h"


@interface ELCImagePickerDemoViewController ()

@property (nonatomic, strong) ALAssetsLibrary *specialLibrary;

@end

@implementation ELCImagePickerDemoViewController

//Using generated synthesizers

- (IBAction)launchController
{
	ELCImagePickerController *elcPicker = [[ELCImagePickerController alloc] initImagePicker];

    elcPicker.maximumImagesCount = 100; //Set the maximum number of images to select to 100
    elcPicker.returnsOriginalImage = YES; //Only return the fullScreenImage, not the fullResolutionImage
    elcPicker.returnsImage = YES; //Return UIimage if YES. If NO, only return asset location information
    elcPicker.onOrder = YES; //For multiple image selection, display and return order of selected images
    elcPicker.mediaTypes = @[(NSString *)kUTTypeImage, (NSString *)kUTTypeMovie]; //Supports image and movie types

	elcPicker.imagePickerDelegate = self;
    
    [self presentViewController:elcPicker animated:YES completion:nil];
}

- (IBAction)launchSpecialController
{
    //add photo framework for ios 8 and above
    
    if(!IS_IOS8) {
        ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
        self.specialLibrary = library;
        NSMutableArray *groups = [NSMutableArray array];
        [_specialLibrary enumerateGroupsWithTypes:ALAssetsGroupSavedPhotos usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
            if (group) {
                [groups addObject:group];
            } else {
                // this is the end
                [self displayPickerForGroup:[groups objectAtIndex:0]];
            }
        } failureBlock:^(NSError *error) {
            self.chosenImages = nil;
            UIAlertView * alert = [[UIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"Album Error: %@ - %@", [error localizedDescription], [error localizedRecoverySuggestion]] delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
            [alert show];
            
            NSLog(@"A problem occured %@", [error description]);
            // an error here means that the asset groups were inaccessable.
            // Maybe the user or system preferences refused access.
        }];
    }else {
        //Get All Saved Photos
        //Fetch PHAssetCollections:
        PHFetchOptions *options = [[PHFetchOptions alloc] init];
        options.predicate = [NSPredicate predicateWithFormat:@"mediaType in %@", @[@(PHAssetMediaTypeImage)]];
        options.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
        PHFetchResult *assetsFetchResult = [PHAsset fetchAssetsWithOptions:options];
        
        [self displayPickerForGroup:assetsFetchResult];
    }
}

- (void)displayPickerForGroup:(NSObject *)group
{
	ELCAssetTablePicker *tablePicker = [[ELCAssetTablePicker alloc] init];
    tablePicker.singleSelection = YES;
    tablePicker.immediateReturn = YES;
    
	ELCImagePickerController *elcPicker = [[ELCImagePickerController alloc] initWithRootViewController:tablePicker];
    elcPicker.maximumImagesCount = 1;
    elcPicker.imagePickerDelegate = self;
    elcPicker.returnsOriginalImage = YES; //Only return the fullScreenImage, not the fullResolutionImage
    elcPicker.returnsImage = YES; //Return UIimage if YES. If NO, only return asset location information
    elcPicker.onOrder = NO; //For single image selection, do not display and return order of selected images
	tablePicker.parent = elcPicker;
    
    // Move me
    tablePicker.assetGroup = group;
    if (!IS_IOS8) {
        [((ALAssetsGroup*)tablePicker.assetGroup) setAssetsFilter:[ALAssetsFilter allAssets]];
    }
    
    [self presentViewController:elcPicker animated:YES completion:nil];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return YES;
    } else {
        return toInterfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
    }
}

#pragma mark ELCImagePickerControllerDelegate Methods

- (void)elcImagePickerController:(ELCImagePickerController *)picker didFinishPickingMediaWithInfo:(NSArray *)info
{
    [self dismissViewControllerAnimated:YES completion:nil];
	
    for (UIView *v in [_scrollView subviews]) {
        [v removeFromSuperview];
    }
    
	CGRect workingFrame = _scrollView.frame;
	workingFrame.origin.x = 0;
    
    NSMutableArray *images = [NSMutableArray arrayWithCapacity:[info count]];
    if(!IS_IOS8) {
        for (NSDictionary *dict in info) {
            if ([dict objectForKey:UIImagePickerControllerMediaType] == ALAssetTypePhoto){
                if ([dict objectForKey:UIImagePickerControllerOriginalImage]){
                    UIImage* image=[dict objectForKey:UIImagePickerControllerOriginalImage];
                    [images addObject:image];
                    
                    UIImageView *imageview = [[UIImageView alloc] initWithImage:image];
                    [imageview setContentMode:UIViewContentModeScaleAspectFit];
                    imageview.frame = workingFrame;
                    
                    [_scrollView addSubview:imageview];
                    
                    workingFrame.origin.x = workingFrame.origin.x + workingFrame.size.width;
                } else {
                    NSLog(@"UIImagePickerControllerReferenceURL = %@", dict);
                }
            } else if ([dict objectForKey:UIImagePickerControllerMediaType] == ALAssetTypeVideo){
                if ([dict objectForKey:UIImagePickerControllerOriginalImage]){
                    UIImage* image=[dict objectForKey:UIImagePickerControllerOriginalImage];

                    [images addObject:image];
                    
                    UIImageView *imageview = [[UIImageView alloc] initWithImage:image];
                    [imageview setContentMode:UIViewContentModeScaleAspectFit];
                    imageview.frame = workingFrame;
                    
                    [_scrollView addSubview:imageview];
                    
                    workingFrame.origin.x = workingFrame.origin.x + workingFrame.size.width;
                } else {
                    NSLog(@"UIImagePickerControllerReferenceURL = %@", dict);
                }
            } else {
                NSLog(@"Uknown asset type");
            }
        }
    }else {
        for (PHAsset *asset in info) {
            
            
            
            if (asset.mediaType == PHAssetMediaTypeImage){
                
                UIImageView *imageview = [[UIImageView alloc] init];
                [imageview setContentMode:UIViewContentModeScaleAspectFit];
                imageview.frame = workingFrame;
                
                
                PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
                
                // Download from cloud if necessary
                options.networkAccessAllowed = YES;
                options.progressHandler = ^(double progress, NSError *error, BOOL *stop, NSDictionary *info) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        //you can update progress here
                    });
                };
                
                
                [[PHImageManager defaultManager] requestImageForAsset:asset targetSize:workingFrame.size contentMode:PHImageContentModeAspectFit options:options resultHandler:^(UIImage *result, NSDictionary *info) {
                    if (result) {
                        imageview.image = result;
                        [images addObject:result];
                    }
                }];
                
                
                
                [_scrollView addSubview:imageview];
                
                workingFrame.origin.x = workingFrame.origin.x + workingFrame.size.width;
            } else {
                
            }
        }
        
    }
    
    self.chosenImages = images;
	
	[_scrollView setPagingEnabled:YES];
	[_scrollView setContentSize:CGSizeMake(workingFrame.origin.x, workingFrame.size.height)];
}

- (void)elcImagePickerControllerDidCancel:(ELCImagePickerController *)picker
{
    [self dismissViewControllerAnimated:YES completion:nil];
}


@end
