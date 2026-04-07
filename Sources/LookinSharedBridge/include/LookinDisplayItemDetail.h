#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class LookinAttributesGroup, LookinDisplayItem;

@interface LookinDisplayItemDetail : NSObject <NSSecureCoding>

@property(nonatomic, assign) unsigned long displayItemOid;
@property(nonatomic, strong, nullable) NSData *groupScreenshotData;
@property(nonatomic, strong, nullable) NSData *soloScreenshotData;
@property(nonatomic, strong, nullable) NSValue *frameValue;
@property(nonatomic, strong, nullable) NSValue *boundsValue;
@property(nonatomic, strong, nullable) NSNumber *hiddenValue;
@property(nonatomic, strong, nullable) NSNumber *alphaValue;
@property(nonatomic, copy, nullable) NSString *customDisplayTitle;
@property(nonatomic, copy, nullable) NSString *danceUISource;
@property(nonatomic, copy, nullable) NSArray<LookinAttributesGroup *> *attributesGroupList;
@property(nonatomic, copy, nullable) NSArray<LookinAttributesGroup *> *customAttrGroupList;
@property(nonatomic, copy, nullable) NSArray<LookinDisplayItem *> *subitems;
@property(nonatomic, assign) NSInteger failureCode;

@end

NS_ASSUME_NONNULL_END
