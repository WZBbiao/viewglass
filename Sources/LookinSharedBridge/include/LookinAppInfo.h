#import <Foundation/Foundation.h>
#import "LookinDefines.h"

NS_ASSUME_NONNULL_BEGIN

@interface LookinAppInfo : NSObject <NSSecureCoding, NSCopying>

@property(nonatomic, assign) NSUInteger appInfoIdentifier;
@property(nonatomic, assign) BOOL shouldUseCache;
@property(nonatomic, assign) int serverVersion;
@property(nonatomic, copy, nullable) NSString *serverReadableVersion;
@property(nonatomic, assign) int swiftEnabledInLookinServer;
@property(nonatomic, strong, nullable) NSData *screenshotData;
@property(nonatomic, strong, nullable) NSData *appIconData;
@property(nonatomic, copy, nullable) NSString *appName;
@property(nonatomic, copy, nullable) NSString *appBundleIdentifier;
@property(nonatomic, copy, nullable) NSString *deviceDescription;
@property(nonatomic, copy, nullable) NSString *osDescription;
@property(nonatomic, assign) NSUInteger osMainVersion;
@property(nonatomic, assign) LookinAppInfoDevice deviceType;
@property(nonatomic, assign) double screenWidth;
@property(nonatomic, assign) double screenHeight;
@property(nonatomic, assign) double screenScale;

@end

NS_ASSUME_NONNULL_END
