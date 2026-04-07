#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "LookinDefines.h"

NS_ASSUME_NONNULL_BEGIN

@class LookinObject, LookinAttributesGroup, LookinEventHandler;

@interface LookinDisplayItem : NSObject <NSSecureCoding, NSCopying>

@property(nonatomic, copy, nullable) NSArray<LookinDisplayItem *> *subitems;
@property(nonatomic, assign) BOOL isHidden;
@property(nonatomic, assign) float alpha;
@property(nonatomic, assign) CGRect frame;
@property(nonatomic, assign) CGRect bounds;
@property(nonatomic, strong, nullable) NSData *soloScreenshotData;
@property(nonatomic, strong, nullable) NSData *groupScreenshotData;
@property(nonatomic, strong, nullable) LookinObject *viewObject;
@property(nonatomic, strong, nullable) LookinObject *layerObject;
@property(nonatomic, strong, nullable) LookinObject *hostViewControllerObject;
@property(nonatomic, copy, nullable) NSArray<LookinAttributesGroup *> *attributesGroupList;
@property(nonatomic, copy, nullable) NSArray<LookinAttributesGroup *> *customAttrGroupList;
@property(nonatomic, assign) BOOL representedAsKeyWindow;
@property(nonatomic, copy, nullable) NSArray<LookinEventHandler *> *eventHandlers;
@property(nonatomic, assign) BOOL shouldCaptureImage;
@property(nonatomic, strong, nullable) id backgroundColor;
@property(nonatomic, copy, nullable) NSString *customDisplayTitle;
@property(nonatomic, copy, nullable) NSString *danceuiSource;

@property(nonatomic, assign) LookinDoNotFetchScreenshotReason doNotFetchScreenshotReason;
@property(nonatomic, assign) BOOL noPreview;

// Hierarchy navigation (non-coded)
@property(nonatomic, weak, nullable) LookinDisplayItem *superItem;

@end

NS_ASSUME_NONNULL_END
