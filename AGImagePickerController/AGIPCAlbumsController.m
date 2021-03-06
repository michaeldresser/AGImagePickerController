//
//  AGIPCAlbumsController.m
//  AGImagePickerController
//
//  Created by Artur Grigor on 2/16/12.
//  Copyright (c) 2012 - 2013 Artur Grigor. All rights reserved.
//  
//  For the full copyright and license information, please view the LICENSE
//  file that was distributed with this source code.
//  

#import "AGIPCAlbumsController.h"

#import "AGImagePickerController.h"
#import "AGIPCAssetsController.h"
#import "AGPCell.h"

@interface AGIPCAlbumsController ()
{
    NSMutableArray *_assetsGroups;
    AGImagePickerController *_imagePickerController;
}

@property (ag_weak, nonatomic, readonly) NSMutableArray *assetsGroups;

@end

@interface AGIPCAlbumsController ()

- (void)registerForNotifications;
- (void)unregisterFromNotifications;

- (void)didChangeLibrary:(NSNotification *)notification;

- (void)loadAssetsGroups;
- (void)reloadData;

- (void)cancelAction:(id)sender;

@end

@implementation AGIPCAlbumsController

#pragma mark - Properties

@synthesize imagePickerController = _imagePickerController;

- (NSMutableArray *)assetsGroups
{
    if (_assetsGroups == nil)
    {
        _assetsGroups = [[NSMutableArray alloc] init];
        [self loadAssetsGroups];
    }
    
    return _assetsGroups;
}

#pragma mark - Object Lifecycle

- (id)initWithImagePickerController:(AGImagePickerController *)imagePickerController
{
    self = [super initWithStyle:UITableViewStylePlain];
    if (self)
    {
        self.imagePickerController = imagePickerController;
    }
    
    return self;
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self.navigationController setToolbarHidden:YES animated:YES];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Fullscreen
    if (self.imagePickerController.shouldChangeStatusBarStyle) {
        self.wantsFullScreenLayout = YES;
    }
    
    // Setup Notifications
    [self registerForNotifications];
    
    // Navigation Bar Items
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithTitle: @"CANCEL" style: UIBarButtonItemStylePlain target:self action:@selector(cancelAction:)];
	self.navigationItem.leftBarButtonItem = cancelButton;
    
    if ([[[UIDevice currentDevice] systemVersion] compare:@"7" options:NSNumericSearch] != NSOrderedAscending)
    {
        UIBarButtonItem *space = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
        space.width = 11;
        self.navigationItem.leftBarButtonItems = [@[space] arrayByAddingObject: cancelButton];
    }
    else
    {
        self.navigationItem.leftBarButtonItem = cancelButton;
    }
    
    if ([self.tableView respondsToSelector:@selector(separatorInset)])
    {
        self.tableView.separatorInset = UIEdgeInsetsZero;
    }
    
    [self.tableView registerNib: [UINib nibWithNibName: @"AGPCell" bundle: nil] forCellReuseIdentifier: @"Cell"];
    
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    
    // Destroy Notifications
    [self unregisterFromNotifications];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAll;
}

#pragma mark - UITableViewDataSource Methods
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.assetsGroups.count;
    self.title = NSLocalizedStringWithDefaultValue(@"AGIPC.Loading", nil, [NSBundle mainBundle], @"Loading...", nil);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    AGPCell *cell = [self.tableView dequeueReusableCellWithIdentifier: @"Cell"];

    ALAssetsGroup *group = (self.assetsGroups)[indexPath.row];
    [group setAssetsFilter:[ALAssetsFilter allPhotos]];
    NSUInteger numberOfAssets = group.numberOfAssets;
    
    cell.AGPName.text = [NSString stringWithFormat:@"%@", [group valueForProperty:ALAssetsGroupPropertyName]];
    cell.AGPDetail.text = [NSString stringWithFormat:@"%d", numberOfAssets];
    [cell.AGPImage setImage:[UIImage imageWithCGImage:[(ALAssetsGroup *)self.assetsGroups[indexPath.row] posterImage]]];
    
    return cell;
}

#pragma mark - UITableViewDelegate Methods

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    
	AGIPCAssetsController *controller = [[AGIPCAssetsController alloc] initWithImagePickerController:self.imagePickerController andAssetsGroup:self.assetsGroups[indexPath.row]];
	[self.navigationController pushViewController:controller animated:YES];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{	
	return 55;
}

#pragma mark - Private

- (void)loadAssetsGroups
{
    @synchronized(self.assetsGroups)
    {
        __ag_weak AGIPCAlbumsController *weakSelf = self;
        
        [self.assetsGroups removeAllObjects];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            
            @autoreleasepool {
                
                void (^assetGroupEnumerator)(ALAssetsGroup *, BOOL *) = ^(ALAssetsGroup *group, BOOL *stop)
                {
                    @synchronized(self.assetsGroups)
                    {
                        if (group == nil)
                        {
                            return;
                        }
                        
                        if (weakSelf.imagePickerController.shouldShowSavedPhotosOnTop) {
                            if ([[group valueForProperty:ALAssetsGroupPropertyType] intValue] == ALAssetsGroupSavedPhotos) {
                                [self.assetsGroups insertObject:group atIndex:0];
                            } else if ([[group valueForProperty:ALAssetsGroupPropertyType] intValue] > ALAssetsGroupSavedPhotos && self.assetsGroups.count > 0) {
                                [self.assetsGroups insertObject:group atIndex:1];
                            } else {
                                [self.assetsGroups addObject:group];
                            }
                        } else {
                            [self.assetsGroups addObject:group];
                        }
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self reloadData];
                        });
                    }
                };
                
                void (^assetGroupEnumberatorFailure)(NSError *) = ^(NSError *error) {
                    NSLog(@"A problem occured. Error: %@", error.localizedDescription);
                    [self.imagePickerController performSelector:@selector(didFail:) withObject:error];
                };
                
                [[AGImagePickerController defaultAssetsLibrary] enumerateGroupsWithTypes:ALAssetsGroupAll
                                                                              usingBlock:assetGroupEnumerator
                                                                            failureBlock:assetGroupEnumberatorFailure];
                
            }
        });
    }
}

- (void)reloadData
{
    [self.tableView reloadData];
    self.title = NSLocalizedStringWithDefaultValue(@"AGIPC.Albums", nil, [NSBundle mainBundle], @"Albums", nil);
}

- (void)cancelAction:(id)sender
{
    [self.imagePickerController performSelector:@selector(didCancelPickingAssets)];
}

#pragma mark - Notifications

- (void)registerForNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(didChangeLibrary:) 
                                                 name:ALAssetsLibraryChangedNotification 
                                               object:[AGImagePickerController defaultAssetsLibrary]];
}

- (void)unregisterFromNotifications
{
    [[NSNotificationCenter defaultCenter] removeObserver:self 
                                                    name:ALAssetsLibraryChangedNotification 
                                                  object:[AGImagePickerController defaultAssetsLibrary]];
}

- (void)didChangeLibrary:(NSNotification *)notification
{
    [self loadAssetsGroups];
}

@end
