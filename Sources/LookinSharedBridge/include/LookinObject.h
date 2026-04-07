#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class LookinIvarTrace;

@interface LookinObject : NSObject <NSSecureCoding, NSCopying>

@property(nonatomic, assign) unsigned long oid;
@property(nonatomic, copy, nullable) NSString *memoryAddress;
@property(nonatomic, copy, nullable) NSArray<NSString *> *classChainList;
@property(nonatomic, copy, nullable) NSString *specialTrace;
@property(nonatomic, copy, nullable) NSArray<LookinIvarTrace *> *ivarTraces;

- (nullable NSString *)rawClassName;

@end

NS_ASSUME_NONNULL_END
