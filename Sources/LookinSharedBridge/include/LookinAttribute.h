#import <Foundation/Foundation.h>
#import "LookinDefines.h"

NS_ASSUME_NONNULL_BEGIN

@interface LookinAttribute : NSObject <NSSecureCoding, NSCopying>

@property(nonatomic, copy, nullable) LookinAttrIdentifier identifier;
@property(nonatomic, copy, nullable) NSString *displayTitle;
@property(nonatomic, assign) LookinAttrType attrType;
@property(nonatomic, strong, nullable) id value;
@property(nonatomic, strong, nullable) id extraValue;
@property(nonatomic, copy, nullable) NSString *customSetterID;

- (BOOL)isUserCustom;

@end

NS_ASSUME_NONNULL_END
