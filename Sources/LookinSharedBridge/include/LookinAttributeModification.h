#import <Foundation/Foundation.h>
#import "LookinDefines.h"

NS_ASSUME_NONNULL_BEGIN

@interface LookinAttributeModification : NSObject <NSSecureCoding>

@property(nonatomic, assign) unsigned long targetOid;
@property(nonatomic, assign) SEL setterSelector;
@property(nonatomic, assign) SEL getterSelector;
@property(nonatomic, assign) LookinAttrType attrType;
@property(nonatomic, strong, nullable) id value;
@property(nonatomic, copy, nullable) NSString *clientReadableVersion;

@end

NS_ASSUME_NONNULL_END
