#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LookinIvarTrace : NSObject <NSSecureCoding>

@property(nonatomic, copy, nullable) NSString *hostClassName;
@property(nonatomic, copy, nullable) NSString *ivarName;

@end

NS_ASSUME_NONNULL_END
