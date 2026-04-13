#import "LookinAppInfo.h"

@implementation LookinAppInfo

+ (BOOL)supportsSecureCoding { return YES; }

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeInt:self.serverVersion forKey:@"serverVersion"];
    [coder encodeObject:self.serverReadableVersion forKey:@"serverReadableVersion"];
    [coder encodeInt:self.swiftEnabledInLookinServer forKey:@"swiftEnabledInLookinServer"];
    [coder encodeObject:self.appIconData forKey:@"1"];
    [coder encodeObject:self.screenshotData forKey:@"2"];
    [coder encodeObject:self.deviceDescription forKey:@"3"];
    [coder encodeObject:self.osDescription forKey:@"4"];
    [coder encodeObject:self.appName forKey:@"5"];
    [coder encodeDouble:self.screenWidth forKey:@"6"];
    [coder encodeDouble:self.screenHeight forKey:@"7"];
    [coder encodeObject:@(self.deviceType) forKey:@"8"];
    [coder encodeObject:self.appBundleIdentifier forKey:@"appBundleIdentifier"];
    [coder encodeObject:@(self.osMainVersion) forKey:@"osMainVersion"];
    [coder encodeDouble:self.screenScale forKey:@"screenScale"];
    [coder encodeObject:@(self.appInfoIdentifier) forKey:@"appInfoIdentifier"];
    [coder encodeBool:self.shouldUseCache forKey:@"shouldUseCache"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [super init]) {
        _serverVersion = [coder decodeIntForKey:@"serverVersion"];
        _serverReadableVersion = [coder decodeObjectOfClass:[NSString class] forKey:@"serverReadableVersion"];
        _swiftEnabledInLookinServer = [coder decodeIntForKey:@"swiftEnabledInLookinServer"];
        _appIconData = [coder decodeObjectOfClass:[NSData class] forKey:@"1"];
        _screenshotData = [coder decodeObjectOfClass:[NSData class] forKey:@"2"];
        _deviceDescription = [coder decodeObjectOfClass:[NSString class] forKey:@"3"];
        _osDescription = [coder decodeObjectOfClass:[NSString class] forKey:@"4"];
        _appName = [coder decodeObjectOfClass:[NSString class] forKey:@"5"];
        _screenWidth = [coder decodeDoubleForKey:@"6"];
        _screenHeight = [coder decodeDoubleForKey:@"7"];
        NSNumber *deviceTypeNum = [coder decodeObjectOfClass:[NSNumber class] forKey:@"8"];
        _deviceType = deviceTypeNum ? deviceTypeNum.unsignedIntegerValue : LookinAppInfoDeviceSimulator;
        _appBundleIdentifier = [coder decodeObjectOfClass:[NSString class] forKey:@"appBundleIdentifier"];
        NSNumber *osMain = [coder decodeObjectOfClass:[NSNumber class] forKey:@"osMainVersion"];
        _osMainVersion = osMain ? osMain.unsignedIntegerValue : 0;
        _screenScale = [coder decodeDoubleForKey:@"screenScale"];
        NSNumber *appInfoId = [coder decodeObjectOfClass:[NSNumber class] forKey:@"appInfoIdentifier"];
        _appInfoIdentifier = appInfoId ? appInfoId.unsignedIntegerValue : 0;
        _shouldUseCache = [coder decodeBoolForKey:@"shouldUseCache"];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    LookinAppInfo *copy = [LookinAppInfo new];
    copy.serverVersion = self.serverVersion;
    copy.serverReadableVersion = self.serverReadableVersion;
    copy.appName = self.appName;
    copy.appBundleIdentifier = self.appBundleIdentifier;
    copy.deviceDescription = self.deviceDescription;
    copy.osDescription = self.osDescription;
    copy.osMainVersion = self.osMainVersion;
    copy.deviceType = self.deviceType;
    copy.screenWidth = self.screenWidth;
    copy.screenHeight = self.screenHeight;
    copy.screenScale = self.screenScale;
    copy.appInfoIdentifier = self.appInfoIdentifier;
    copy.shouldUseCache = self.shouldUseCache;
    return copy;
}

@end
