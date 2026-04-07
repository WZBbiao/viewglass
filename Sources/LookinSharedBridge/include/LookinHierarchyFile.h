#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class LookinHierarchyInfo;

@interface LookinHierarchyFile : NSObject <NSSecureCoding>

@property(nonatomic, assign) int serverVersion;
@property(nonatomic, strong, nullable) LookinHierarchyInfo *hierarchyInfo;
@property(nonatomic, copy, nullable) NSDictionary<NSNumber *, NSData *> *soloScreenshots;
@property(nonatomic, copy, nullable) NSDictionary<NSNumber *, NSData *> *groupScreenshots;

+ (BOOL)verifyHierarchyFile:(nullable LookinHierarchyFile *)file;

@end

NS_ASSUME_NONNULL_END
