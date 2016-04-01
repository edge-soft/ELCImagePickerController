//
//  ELCAssetTablePicker.m
//
//  Created by ELC on 2/15/11.
//  Copyright 2011 ELC Technologies. All rights reserved.
//

#import "ELCAssetTablePicker.h"
#import "ELCAssetCell.h"
#import "ELCAsset.h"
#import "ELCAlbumPickerController.h"
#import "ELCConsole.h"
#import "ELCConstants.h"
#import <Photos/Photos.h>


@interface ELCAssetTablePicker () <PHPhotoLibraryChangeObserver>





@property (nonatomic, assign) int columns;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIToolbar *toolbar;

@end

@implementation ELCAssetTablePicker

static NSInteger const kELCAssetTablePickerColumns = 4;
static CGFloat const kELCAssetCellPadding = 1.0f;
static CGFloat const kELCAssetDefaultItemWidth = 100.0f;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    //Sets a reasonable default bigger then 0 for columns
    //So that we don't have a divide by 0 scenario
    self.columns = kELCAssetTablePickerColumns;
    

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds];
    [self.tableView setSeparatorStyle:UITableViewCellSeparatorStyleNone];
	[self.tableView setAllowsSelection:NO];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    
    [self.view addSubview:self.tableView];
    
    //Ensure that the the table has the same padding above the first row and below the last row
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.tableView.frame.size.width, kELCAssetCellPadding)];
    
    //Toolbar
    if ([ELCConsole mainConsole].enableToolbar) {
        [self.view addSubview:self.toolbar];
        [self updateToolbarAppearance];
        [self setupToolbarItems];
        [self setToolbarHidden:YES animated:NO];
    }

    NSMutableArray *tempArray = [[NSMutableArray alloc] init];
    self.elcAssets = tempArray;
    self.elcAssetsLock = [[NSLock alloc] init];
    
    if (self.immediateReturn) {
        
    } else {
        UIBarButtonItem *doneButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneAction:)];
        [self.navigationItem setRightBarButtonItem:doneButtonItem];
        [self.navigationItem setTitle:NSLocalizedString(@"Loading...", nil)];
    }

	
    
    // Register for notifications when the photo library has changed
    
        [[PHPhotoLibrary sharedPhotoLibrary] registerChangeObserver:self];
    
    
    [self performSelectorInBackground:@selector(preparePhotos) withObject:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    
}
- (void)viewDidLayoutSubviews {
    self.columns = self.view.bounds.size.width / kELCAssetDefaultItemWidth;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [[ELCConsole mainConsole] removeAllIndex];
    
    
        [[PHPhotoLibrary sharedPhotoLibrary] unregisterChangeObserver:self];
    

}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return YES;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    self.columns = self.view.bounds.size.width / kELCAssetDefaultItemWidth;
    self.tableView.frame = self.view.bounds;

    [self.tableView reloadData];
    
    //Update toolbar frame
    _toolbar.frame = [self frameForToolbarAtOrientation:[self statusOrientation]];
    [self setupToolbarItems];
}

- (void)preparePhotos
{
    @autoreleasepool {
//        if (self.elcAssets == nil) {
//            self.elcAssets = [[NSMutableArray alloc] init];
//        }
        [self.elcAssetsLock lock];
        [self.elcAssets removeAllObjects];
        
            PHFetchResult *tempFetchResult = (PHFetchResult *)self.assetGroup;
        NSLog(@"Totoal results in the ground: %lu", (unsigned long)tempFetchResult.count);
            for (int k =0; k < tempFetchResult.count; k++) {
                PHAsset *asset = tempFetchResult[k];
                ELCAsset *elcAsset = [[ELCAsset alloc] initWithAsset:asset];
                [elcAsset setParent:self];
                
                BOOL isAssetFiltered = NO;
                if (self.assetPickerFilterDelegate &&
                    [self.assetPickerFilterDelegate respondsToSelector:@selector(assetTablePicker:isAssetFilteredOut:)])
                {
                    isAssetFiltered = [self.assetPickerFilterDelegate assetTablePicker:self isAssetFilteredOut:(ELCAsset*)elcAsset];
                }
                
                if (!isAssetFiltered) {
                    [self.elcAssets addObject:elcAsset];
                }
            }
        [self.elcAssetsLock unlock];
        
            dispatch_sync(dispatch_get_main_queue(), ^{
                [self.tableView reloadData];
                // scroll to bottom
                long section = [self numberOfSectionsInTableView:self.tableView] - 1;
                long row = [self tableView:self.tableView numberOfRowsInSection:section] - 1;
                if (section >= 0 && row >= 0) {
                    NSIndexPath *ip = [NSIndexPath indexPathForRow:row
                                                         inSection:section];
                    [self.tableView scrollToRowAtIndexPath:ip
                                          atScrollPosition:UITableViewScrollPositionBottom
                                                  animated:NO];
                }
                
                [self.navigationItem setTitle:self.singleSelection ? NSLocalizedString(@"Pick Photo", nil) : NSLocalizedString(@"Pick Photos", nil)];
            });
        
    }
}


- (void)doneAction:(id)sender
{	
    NSMutableArray *selectedAssetsImages = [[NSMutableArray alloc] init];
    [self.elcAssetsLock lock];
	for (ELCAsset *elcAsset in self.elcAssets) {
		if ([elcAsset selected]) {
			[selectedAssetsImages addObject:elcAsset];
		}
	}
    if ([[ELCConsole mainConsole] onOrder]) {
        [selectedAssetsImages sortUsingSelector:@selector(compareWithIndex:)];
    }
    [self.elcAssetsLock unlock];
    [self.parent selectedAssets:selectedAssetsImages];
}


- (BOOL)shouldSelectAsset:(ELCAsset *)asset
{
    NSUInteger selectionCount = 0;
    [self.elcAssetsLock lock];
    for (ELCAsset *elcAsset in self.elcAssets) {
        if (elcAsset.selected) selectionCount++;
    }
    [self.elcAssetsLock unlock];
    BOOL shouldSelect = YES;
    if ([self.parent respondsToSelector:@selector(shouldSelectAsset:previousCount:)]) {
        shouldSelect = [self.parent shouldSelectAsset:asset previousCount:selectionCount];
    }
    return shouldSelect;
}

- (void)assetSelected:(ELCAsset *)asset
{
    if (self.singleSelection) {
        [self.elcAssetsLock lock];
        for (ELCAsset *elcAsset in self.elcAssets) {
            if (asset != elcAsset) {
                elcAsset.selected = NO;
            }
        }
        [self.elcAssetsLock unlock];
    }
    if (self.immediateReturn) {
        NSArray *singleAssetArray = @[asset];
        [(NSObject *)self.parent performSelector:@selector(selectedAssets:) withObject:singleAssetArray afterDelay:0];
    }
    
    if (_toolbar.alpha == 1)
        return;
    
//    [self showToolbar];
}

- (BOOL)shouldDeselectAsset:(ELCAsset *)asset
{
    if (self.immediateReturn){
        return NO;
    }
    return YES;
}

- (void)assetDeselected:(ELCAsset *)asset
{
    if (self.singleSelection) {
        [self.elcAssetsLock lock];
        for (ELCAsset *elcAsset in self.elcAssets) {
            if (asset != elcAsset) {
                elcAsset.selected = NO;
            }
        }
        [self.elcAssetsLock unlock];
    }

    if (self.immediateReturn) {
        NSArray *singleAssetArray = @[asset.asset];
        [(NSObject *)self.parent performSelector:@selector(selectedAssets:) withObject:singleAssetArray afterDelay:0];
    }
    
    int numOfSelectedElements = [[ELCConsole mainConsole] numOfSelectedElements];
    if (asset.index < numOfSelectedElements - 1) {
        NSMutableArray *arrayOfCellsToReload = [[NSMutableArray alloc] initWithCapacity:1];
        [self.elcAssetsLock lock];
        for (int i = 0; i < [self.elcAssets count]; i++) {
            ELCAsset *assetInArray = [self.elcAssets objectAtIndex:i];
            if (assetInArray.selected && (assetInArray.index > asset.index)) {
                assetInArray.index -= 1;
                
                int row = i / self.columns;
                NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:0];
                BOOL indexExistsInArray = NO;
                for (NSIndexPath *indexInArray in arrayOfCellsToReload) {
                    if (indexInArray.row == indexPath.row) {
                        indexExistsInArray = YES;
                        break;
                    }
                }
                if (!indexExistsInArray) {
                    [arrayOfCellsToReload addObject:indexPath];
                }
            }
        }
        [self.elcAssetsLock unlock];
        [self.tableView reloadRowsAtIndexPaths:arrayOfCellsToReload withRowAnimation:UITableViewRowAnimationNone];
    }
    
    //If there are no photo selected then hide Toolbar
    if ([self totalSelectedAssets] == 0)
        [self hideToolbar];
}

- (void)assetSelectAll {
    [self.elcAssetsLock lock];
    for (int i = 0; i < self.elcAssets.count; i++) {
        ELCAsset *elcAsset = [self.elcAssets objectAtIndex:i];
        if (elcAsset.selected)
            continue;
        
        elcAsset.selected = YES;
        
        //Incase reached limit of selection
        if (!elcAsset.selected) {
            break;
        }
        
        elcAsset.index = [[ELCConsole mainConsole] numOfSelectedElements];
        [[ELCConsole mainConsole] addIndex:elcAsset.index];
    }
    [self.elcAssetsLock unlock];
    [self.tableView reloadData];
}

- (void)assetDeselectAll {
    [self.elcAssetsLock lock];
    for (ELCAsset *elcAsset in self.elcAssets) {
        elcAsset.selected = NO;
    }
    [self.elcAssetsLock unlock];
    [[ELCConsole mainConsole] removeAllIndex];
    
    [self.tableView reloadData];
}

#pragma mark UITableViewDataSource Delegate Methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (self.columns <= 0) { //Sometimes called before we know how many columns we have
        self.columns = kELCAssetTablePickerColumns;
    }
    [self.elcAssetsLock lock];
    NSInteger res = ceil([self.elcAssets count] / (float)self.columns);
    [self.elcAssetsLock unlock];
    return res;
}

- (NSArray *)assetsForIndexPath:(NSIndexPath *)path
{
    long index = path.row * self.columns;
    long length = MIN(self.columns, [self.elcAssets count] - index);
    [self.elcAssetsLock lock];
    NSArray *res = [self.elcAssets subarrayWithRange:NSMakeRange(index, length)];
    [self.elcAssetsLock unlock];
    return res;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{    
    static NSString *CellIdentifier = @"Cell";
        
    ELCAssetCell *cell = (ELCAssetCell*)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];

    if (cell == nil) {		        
        cell = [[ELCAssetCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    cell.itemPadding = kELCAssetCellPadding;
    cell.numberOfColumns = self.columns;

    cell.parent = self;
    
    [cell setAssets:[self assetsForIndexPath:indexPath]];
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat height = ceilf((tableView.frame.size.width - (self.columns+1) * kELCAssetCellPadding) / self.columns + kELCAssetCellPadding);
    return height;
}

- (int)totalSelectedAssets
{
    int count = 0;
    [self.elcAssetsLock lock];
    for (ELCAsset *asset in self.elcAssets) {
		if (asset.selected) {
            count++;	
		}
	}
    [self.elcAssetsLock unlock];
    
    return count;
}

#pragma mark - Photo Library Observer 

-(void)photoLibraryDidChange:(PHChange *)changeInstance {
//    PHFetchResultChangeDetails *changeDetails = [changeInstance changeDetailsForFetchResult:(PHFetchResult*)self.assetGroup];
    
//    if(changeDetails) {
//        self.assetGroup = [changeDetails fetchResultAfterChanges];
//        [self preparePhotos];
//    }
}

#pragma mark - Toolbar
- (UIToolbar *)toolbar {
    if (!_toolbar) {
        _toolbar = [[UIToolbar alloc] initWithFrame:[self frameForToolbarAtOrientation:[self statusOrientation]]];
        _toolbar.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    }
    
    return _toolbar;
}

- (void)updateToolbarAppearance {
    _toolbar.barStyle = [ELCConsole mainConsole].toolbarStyle;
    _toolbar.tintColor = [ELCConsole mainConsole].toolbarTintColor;
    _toolbar.barTintColor = [ELCConsole mainConsole].toolbarBarTintColor;
    [_toolbar setBackgroundImage:[ELCConsole mainConsole].toolbarBackgroundImage forToolbarPosition:UIBarPositionAny barMetrics:UIBarMetricsDefault];
    [_toolbar setBackgroundImage:[ELCConsole mainConsole].toolbarBackgroundImage forToolbarPosition:UIBarPositionAny barMetrics:UIBarMetricsCompact];
}

- (void)setupToolbarItems {
    CGSize buttonSize = CGSizeMake(_toolbar.frame.size.width/2, _toolbar.frame.size.height);
    
    UIButton *templateButton = [UIButton buttonWithType:UIButtonTypeSystem];
    templateButton.frame = CGRectMake(0, 0, buttonSize.width, buttonSize.height);
    [templateButton setTitle:@"Select All" forState:UIControlStateNormal];
    [templateButton addTarget:self action:@selector(assetSelectAll) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *selectAllButton = [[UIBarButtonItem alloc] initWithCustomView:templateButton];

    templateButton = [UIButton buttonWithType:UIButtonTypeSystem];
    templateButton.frame = CGRectMake(buttonSize.width, 0, buttonSize.width, buttonSize.height);
    [templateButton setTitle:@"Deselect All" forState:UIControlStateNormal];
    [templateButton addTarget:self action:@selector(assetDeselectAll) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *deselectAllButton = [[UIBarButtonItem alloc] initWithCustomView:templateButton];
    
    UIBarButtonItem *negativeSeparator = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    negativeSeparator.width = -16;
    
    [_toolbar setItems:@[negativeSeparator, selectAllButton, negativeSeparator, deselectAllButton]];
}

- (void)showToolbar { [self setToolbarHidden:NO animated:YES]; }
- (void)hideToolbar { [self setToolbarHidden:YES animated:YES]; }

- (void)setToolbarHidden:(BOOL)hidden animated:(BOOL)animated {
    
    CGFloat alpha = hidden ? 0 : 1;
    CGFloat animateDuration = animated ? 0.3 : 0;
    CGFloat animatonOffset = 20;
    
    [UIView animateWithDuration:animateDuration animations:^{
        _toolbar.frame = [self frameForToolbarAtOrientation:[self statusOrientation]];
        
        if (hidden) {
            _toolbar.frame = CGRectOffset(_toolbar.frame, 0, animatonOffset);
            _tableView.frame = self.view.bounds;
        } else {
            CGRect frame = _tableView.frame;
            frame.size.height = frame.size.height - _toolbar.frame.size.height;
            _tableView.frame = frame;
        }
        
        _toolbar.alpha = alpha;
    }];
}

#pragma mark - Frame Calculation

- (CGRect)frameForToolbarAtOrientation:(UIInterfaceOrientation)orientation {
    CGFloat height = 44;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone &&
        UIInterfaceOrientationIsLandscape(orientation)) height = 32;
    return CGRectIntegral(CGRectMake(0, self.view.bounds.size.height - height, self.view.bounds.size.width, height));
}

- (UIInterfaceOrientation)statusOrientation {
    return [[UIApplication sharedApplication] statusBarOrientation];
}

@end
