#import <Foundation/Foundation.h>
#import "LookinDefines.h"

NS_ASSUME_NONNULL_BEGIN

@class LookinAttribute;

@interface LookinAttributesSection : NSObject <NSSecureCoding, NSCopying>

@property(nonatomic, copy, nullable) NSString *identifier;
@property(nonatomic, copy, nullable) NSArray<LookinAttribute *> *attributes;

@end

NS_ASSUME_NONNULL_END
