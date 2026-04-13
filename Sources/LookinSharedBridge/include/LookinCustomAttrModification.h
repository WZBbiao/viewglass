#import <Foundation/Foundation.h>
#import "LookinDefines.h"

NS_ASSUME_NONNULL_BEGIN

@interface LookinCustomAttrModification : NSObject <NSSecureCoding>

@property(nonatomic, assign) LookinAttrType attrType;
@property(nonatomic, copy, nullable) NSString *customSetterID;
@property(nonatomic, strong, nullable) id value;

@end

NS_ASSUME_NONNULL_END
