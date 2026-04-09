#ifndef LookinDefines_h
#define LookinDefines_h

#import <Foundation/Foundation.h>

// Server/Client version constants
static const int LOOKIN_SERVER_VERSION = 7;
static NSString * const _Nonnull LOOKIN_SERVER_READABLE_VERSION = @"1.2.8";
static const int LOOKIN_CLIENT_VERSION = 7;
static const int LOOKIN_SUPPORTED_SERVER_MIN = 7;
static const int LOOKIN_SUPPORTED_SERVER_MAX = 7;

// Port constants
static const int LookinSimulatorIPv4PortNumberStart = 47164;
static const int LookinSimulatorIPv4PortNumberEnd = 47169;
static const int LookinUSBDeviceIPv4PortNumberStart = 47175;
static const int LookinUSBDeviceIPv4PortNumberEnd = 47179;

// Request types — use plain constants for reliable Swift import
static const uint32_t LookinRequestTypePing = 200;
static const uint32_t LookinRequestTypeApp = 201;
static const uint32_t LookinRequestTypeHierarchy = 202;
static const uint32_t LookinRequestTypeHierarchyDetails = 203;
static const uint32_t LookinRequestTypeInbuiltAttrModification = 204;
static const uint32_t LookinRequestTypeAttrModificationPatch = 205;
static const uint32_t LookinRequestTypeInvokeMethod = 206;
static const uint32_t LookinRequestTypeFetchObject = 207;
static const uint32_t LookinRequestTypeFetchImageViewImage = 208;
static const uint32_t LookinRequestTypeModifyRecognizerEnable = 209;
static const uint32_t LookinRequestTypeAllAttrGroups = 210;
static const uint32_t LookinRequestTypeAllSelectorNames = 213;
static const uint32_t LookinRequestTypeCustomAttrModification = 214;
static const uint32_t LookinRequestTypeSemanticTap = 215;
static const uint32_t LookinRequestTypeSemanticLongPress = 216;
static const uint32_t LookinRequestTypeHighResolutionScreenshot = 217;
static const uint32_t LookinRequestTypeSemanticDismiss = 218;

// Push types
static const uint32_t LookinPush_BringForwardScreenshotTask = 303;
static const uint32_t LookinPush_CancelHierarchyDetails = 304;

// Coding value types
typedef NS_ENUM(NSInteger, LookinCodingValueType) {
    LookinCodingValueTypeUnknown = 0,
    LookinCodingValueTypeChar,
    LookinCodingValueTypeDouble,
    LookinCodingValueTypeFloat,
    LookinCodingValueTypeLongLong,
    LookinCodingValueTypeBOOL,
    LookinCodingValueTypeColor,
    LookinCodingValueTypeEnum,
    LookinCodingValueTypeImage,
};

// Attr types
typedef NS_ENUM(NSInteger, LookinAttrType) {
    LookinAttrTypeNone = 0,
    LookinAttrTypeVoid,
    LookinAttrTypeChar,
    LookinAttrTypeInt,
    LookinAttrTypeShort,
    LookinAttrTypeLong,
    LookinAttrTypeLongLong,
    LookinAttrTypeUnsignedChar,
    LookinAttrTypeUnsignedInt,
    LookinAttrTypeUnsignedShort,
    LookinAttrTypeUnsignedLong,
    LookinAttrTypeUnsignedLongLong,
    LookinAttrTypeFloat,
    LookinAttrTypeDouble,
    LookinAttrTypeBOOL,
    LookinAttrTypeSel,
    LookinAttrTypeClass,
    LookinAttrTypeCGPoint,
    LookinAttrTypeCGVector,
    LookinAttrTypeCGSize,
    LookinAttrTypeCGRect,
    LookinAttrTypeCGAffineTransform,
    LookinAttrTypeUIEdgeInsets,
    LookinAttrTypeUIOffset,
    LookinAttrTypeNSString,
    LookinAttrTypeEnumInt,
    LookinAttrTypeEnumLong,
    LookinAttrTypeUIColor,
    LookinAttrTypeCustomObj,
    LookinAttrTypeEnumString,
    LookinAttrTypeShadow,
    LookinAttrTypeJson,
};

// Device type
typedef NS_ENUM(NSUInteger, LookinAppInfoDevice) {
    LookinAppInfoDeviceSimulator = 0,
    LookinAppInfoDeviceiPad,
    LookinAppInfoDeviceOthers,
};

// Async update task type
typedef NS_ENUM(NSInteger, LookinStaticAsyncUpdateTaskType) {
    LookinStaticAsyncUpdateTaskTypeSoloScreenshot = 0,
    LookinStaticAsyncUpdateTaskTypeGroupScreenshot,
    LookinStaticAsyncUpdateTaskTypeNoScreenshot,
};

typedef NS_ENUM(NSInteger, LookinDetailUpdateTaskAttrRequest) {
    LookinDetailUpdateTaskAttrRequest_NotNeed = 0,
    LookinDetailUpdateTaskAttrRequest_Need,
};

// Screenshot reason
typedef NS_ENUM(NSInteger, LookinDoNotFetchScreenshotReason) {
    LookinFetchScreenshotPermitted = 0,
    LookinDoNotFetchScreenshotForTooLarge,
    LookinDoNotFetchScreenshotForUserConfig,
};

// Error domain & codes
static NSString * const _Nonnull LookinErrorDomain = @"LookinErrorDomain";

typedef NS_ENUM(NSInteger, LookinErrCode) {
    LookinErrCode_ServerVersionTooLow = 100,
    LookinErrCode_ServerVersionTooHigh = 101,
    LookinErrCode_Discard = 102,
    LookinErrCode_Timeout = 103,
    LookinErrCode_PeerTalk = 104,
    LookinErrCode_PingFailForBackgroundState = 105,
    LookinErrCode_ObjectNotFound = 106,
    LookinErrCode_Inner = 107,
    LookinErrCode_UnsupportedFileType = 108,
};

// Special return flag
static NSString * const _Nonnull LookinStringFlag_VoidReturn = @"LookinStringFlag_VoidReturn";

// Attr group identifier type
typedef NSString * LookinAttrGroupIdentifier;
typedef NSString * LookinAttrIdentifier;

#endif /* LookinDefines_h */
