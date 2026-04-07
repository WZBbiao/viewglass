#import <Foundation/Foundation.h>
#import "LookinDefines.h"

NS_ASSUME_NONNULL_BEGIN

@class LookinAttributesSection;

@interface LookinAttributesGroup : NSObject <NSSecureCoding, NSCopying>

@property(nonatomic, copy, nullable) NSString *userCustomTitle;
@property(nonatomic, copy, nullable) LookinAttrGroupIdentifier identifier;
@property(nonatomic, copy, nullable) NSArray<LookinAttributesSection *> *attrSections;

- (NSString *)uniqueKey;
- (BOOL)isUserCustom;

@end

NS_ASSUME_NONNULL_END
