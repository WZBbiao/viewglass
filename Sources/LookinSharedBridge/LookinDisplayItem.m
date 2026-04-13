#import "LookinDisplayItem.h"
#import "LookinObject.h"
#import "LookinAttributesGroup.h"
#import "LookinEventHandler.h"

@implementation LookinDisplayItem

+ (BOOL)supportsSecureCoding { return YES; }

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.subitems forKey:@"subitems"];
    [coder encodeBool:self.isHidden forKey:@"isHidden"];
    [coder encodeFloat:self.alpha forKey:@"alpha"];
    [coder encodeObject:[NSValue valueWithBytes:&_frame objCType:@encode(CGRect)] forKey:@"frame"];
    [coder encodeObject:[NSValue valueWithBytes:&_bounds objCType:@encode(CGRect)] forKey:@"bounds"];
    [coder encodeObject:self.soloScreenshotData forKey:@"soloScreenshot"];
    [coder encodeObject:self.groupScreenshotData forKey:@"groupScreenshot"];
    [coder encodeObject:self.viewObject forKey:@"viewObject"];
    [coder encodeObject:self.layerObject forKey:@"layerObject"];
    [coder encodeObject:self.hostViewControllerObject forKey:@"hostViewControllerObject"];
    [coder encodeObject:self.attributesGroupList forKey:@"attributesGroupList"];
    [coder encodeObject:self.customAttrGroupList forKey:@"customAttrGroupList"];
    [coder encodeBool:self.representedAsKeyWindow forKey:@"representedAsKeyWindow"];
    [coder encodeObject:self.eventHandlers forKey:@"eventHandlers"];
    [coder encodeBool:self.shouldCaptureImage forKey:@"shouldCaptureImage"];
    [coder encodeObject:self.customDisplayTitle forKey:@"customDisplayTitle"];
    [coder encodeObject:self.danceuiSource forKey:@"danceuiSource"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [super init]) {
        NSSet *itemClasses = [NSSet setWithArray:@[
            [NSArray class], [LookinDisplayItem class]
        ]];
        _subitems = [coder decodeObjectOfClasses:itemClasses forKey:@"subitems"];
        _isHidden = [coder decodeBoolForKey:@"isHidden"];
        _alpha = [coder decodeFloatForKey:@"alpha"];

        // frame/bounds may come as NSValue (same-platform) or NSString (cross-platform)
        {
            NSSet *rectClasses = [NSSet setWithArray:@[[NSValue class], [NSString class]]];
            id frameObj = [coder decodeObjectOfClasses:rectClasses forKey:@"frame"];
            if ([frameObj isKindOfClass:[NSValue class]]) {
                [frameObj getValue:&_frame];
            } else if ([frameObj isKindOfClass:[NSString class]]) {
                _frame = NSRectToCGRect(NSRectFromString(frameObj));
            }

            id boundsObj = [coder decodeObjectOfClasses:rectClasses forKey:@"bounds"];
            if ([boundsObj isKindOfClass:[NSValue class]]) {
                [boundsObj getValue:&_bounds];
            } else if ([boundsObj isKindOfClass:[NSString class]]) {
                _bounds = NSRectToCGRect(NSRectFromString(boundsObj));
            }
        }

        // Screenshots may come as NSData or platform-specific image objects
        id soloObj = [coder decodeObjectOfClasses:[NSSet setWithArray:@[[NSData class], [NSObject class]]] forKey:@"soloScreenshot"];
        if ([soloObj isKindOfClass:[NSData class]]) _soloScreenshotData = soloObj;

        id groupObj = [coder decodeObjectOfClasses:[NSSet setWithArray:@[[NSData class], [NSObject class]]] forKey:@"groupScreenshot"];
        if ([groupObj isKindOfClass:[NSData class]]) _groupScreenshotData = groupObj;

        _viewObject = [coder decodeObjectOfClass:[LookinObject class] forKey:@"viewObject"];
        _layerObject = [coder decodeObjectOfClass:[LookinObject class] forKey:@"layerObject"];
        _hostViewControllerObject = [coder decodeObjectOfClass:[LookinObject class] forKey:@"hostViewControllerObject"];

        NSSet *groupClasses = [NSSet setWithArray:@[
            [NSArray class], [LookinAttributesGroup class]
        ]];
        _attributesGroupList = [coder decodeObjectOfClasses:groupClasses forKey:@"attributesGroupList"];
        _customAttrGroupList = [coder decodeObjectOfClasses:groupClasses forKey:@"customAttrGroupList"];
        _representedAsKeyWindow = [coder decodeBoolForKey:@"representedAsKeyWindow"];

        NSSet *handlerClasses = [NSSet setWithArray:@[
            [NSArray class], [LookinEventHandler class]
        ]];
        _eventHandlers = [coder decodeObjectOfClasses:handlerClasses forKey:@"eventHandlers"];
        _shouldCaptureImage = [coder decodeBoolForKey:@"shouldCaptureImage"];
        _customDisplayTitle = [coder decodeObjectOfClass:[NSString class] forKey:@"customDisplayTitle"];
        _danceuiSource = [coder decodeObjectOfClass:[NSString class] forKey:@"danceuiSource"];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    LookinDisplayItem *copy = [LookinDisplayItem new];
    copy.subitems = self.subitems;
    copy.isHidden = self.isHidden;
    copy.alpha = self.alpha;
    copy.frame = self.frame;
    copy.bounds = self.bounds;
    copy.viewObject = self.viewObject;
    copy.layerObject = self.layerObject;
    copy.hostViewControllerObject = self.hostViewControllerObject;
    copy.customDisplayTitle = self.customDisplayTitle;
    return copy;
}

@end
