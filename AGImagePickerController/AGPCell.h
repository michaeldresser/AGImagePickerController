//
//  AGPCell.h
//  Pods
//
//  Created by Michael Dresser on 3/20/14.
//
//

#import <UIKit/UIKit.h>

@interface AGPCell : UITableViewCell
@property (unsafe_unretained, nonatomic) IBOutlet UIImageView *AGPImage;
@property (unsafe_unretained, nonatomic) IBOutlet UILabel *AGPName;
@property (unsafe_unretained, nonatomic) IBOutlet UILabel *AGPDetail;
@end
