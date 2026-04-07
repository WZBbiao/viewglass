#import "LookinDisplayItemDetail.h"
#import "LookinAttributesGroup.h"
#import "LookinDisplayItem.h"

@implementation LookinDisplayItemDetail

+ (BOOL)supportsSecureCoding { return YES; }

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:@(self.displayItemOid) forKey:@"displayItemOid"];
    [coder encodeObject:self.groupScreenshotData forKey:@"groupScreenshot"];
    [coder encodeObject:self.soloScreenshotData forKey:@"soloScreenshot"];
    [coder encodeObject:self.frameValue forKey:@"frameValue"];
    [coder encodeObject:self.boundsValue forKey:@"boundsValue"];
    [coder encodeObject:self.hiddenValue forKey:@"hiddenValue"];
    [coder encodeObject:self.alphaValue forKey:@"alphaValue"];
    [coder encodeObject:self.customDisplayTitle forKey:@"customDisplayTitle"];
    [coder encodeObject:self.danceUISource forKey:@"danceUISource"];
    [coder encodeObject:self.attributesGroupList forKey:@"attributesGroupList"];
    [coder encodeObject:self.customAttrGroupList forKey:@"customAttrGroupList"];
    [coder encodeObject:self.subitems forKey:@"subitems"];
    [coder encodeInteger:self.failureCode forKey:@"failureCode"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [super init]) {
        NSNumber *oidNum = [coder decodeObjectOfClass:[NSNumber class] forKey:@"displayItemOid"];
        _displayItemOid = oidNum ? oidNum.unsignedLongValue : 0;
        _groupScreenshotData = [coder decodeObjectOfClass:[NSData class] forKey:@"groupScreenshot"];
        _soloScreenshotData = [coder decodeObjectOfClass:[NSData class] forKey:@"soloScreenshot"];
        _frameValue = [coder decodeObjectOfClass:[NSValue class] forKey:@"frameValue"];
        _boundsValue = [coder decodeObjectOfClass:[NSValue class] forKey:@"boundsValue"];
        _hiddenValue = [coder decodeObjectOfClass:[NSNumber class] forKey:@"hiddenValue"];
        _alphaValue = [coder decodeObjectOfClass:[NSNumber class] forKey:@"alphaValue"];
        _customDisplayTitle = [coder decodeObjectOfClass:[NSString class] forKey:@"customDisplayTitle"];
        _danceUISource = [coder decodeObjectOfClass:[NSString class] forKey:@"danceUISource"];
        NSSet *groupClasses = [NSSet setWithArray:@[[NSArray class], [LookinAttributesGroup class]]];
        _attributesGroupList = [coder decodeObjectOfClasses:groupClasses forKey:@"attributesGroupList"];
        _customAttrGroupList = [coder decodeObjectOfClasses:groupClasses forKey:@"customAttrGroupList"];
        NSSet *itemClasses = [NSSet setWithArray:@[[NSArray class], [LookinDisplayItem class]]];
        _subitems = [coder decodeObjectOfClasses:itemClasses forKey:@"subitems"];
        _failureCode = [coder decodeIntegerForKey:@"failureCode"];
    }
    return self;
}

@end
