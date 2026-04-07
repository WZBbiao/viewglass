#import <Foundation/Foundation.h>
#import "LookinDefines.h"

NS_ASSUME_NONNULL_BEGIN

@interface LookinConnectionAttachment : NSObject <NSSecureCoding>

@property(nonatomic, assign) LookinCodingValueType dataType;
@property(nonatomic, strong, nullable) id data;

@end

NS_ASSUME_NONNULL_END
