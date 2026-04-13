#import "LookinConnectionAttachment.h"

NS_ASSUME_NONNULL_BEGIN

@interface LookinConnectionResponseAttachment : LookinConnectionAttachment

@property(nonatomic, assign) int lookinServerVersion;
@property(nonatomic, strong, nullable) NSError *error;
@property(nonatomic, assign) BOOL appIsInBackground;
@property(nonatomic, assign) NSUInteger dataTotalCount;
@property(nonatomic, assign) NSUInteger currentDataCount;

+ (instancetype)attachmentWithError:(NSError *)error;

@end

NS_ASSUME_NONNULL_END
