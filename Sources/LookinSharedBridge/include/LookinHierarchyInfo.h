#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class LookinDisplayItem, LookinAppInfo;

@interface LookinHierarchyInfo : NSObject <NSSecureCoding, NSCopying>

@property(nonatomic, copy, nullable) NSArray<LookinDisplayItem *> *displayItems;
@property(nonatomic, copy, nullable) NSDictionary<NSString *, id> *colorAlias;
@property(nonatomic, copy, nullable) NSArray<NSString *> *collapsedClassList;
@property(nonatomic, strong, nullable) LookinAppInfo *appInfo;
@property(nonatomic, assign) int serverVersion;

@end

NS_ASSUME_NONNULL_END
