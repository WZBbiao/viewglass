#import "LookinHierarchyInfo.h"
#import "LookinDisplayItem.h"
#import "LookinAppInfo.h"

@implementation LookinHierarchyInfo

+ (BOOL)supportsSecureCoding { return YES; }

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.displayItems forKey:@"1"];
    [coder encodeObject:self.appInfo forKey:@"2"];
    [coder encodeObject:self.colorAlias forKey:@"3"];
    [coder encodeObject:self.collapsedClassList forKey:@"4"];
    [coder encodeInt:self.serverVersion forKey:@"serverVersion"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [super init]) {
        NSSet *itemClasses = [NSSet setWithArray:@[
            [NSArray class], [NSMutableArray class], [LookinDisplayItem class]
        ]];
        _displayItems = [coder decodeObjectOfClasses:itemClasses forKey:@"1"];
        _appInfo = [coder decodeObjectOfClass:[LookinAppInfo class] forKey:@"2"];
        _colorAlias = [coder decodeObjectOfClasses:[NSSet setWithArray:@[
            [NSDictionary class], [NSString class], [NSArray class], [NSNumber class]
        ]] forKey:@"3"];
        _collapsedClassList = [coder decodeObjectOfClasses:[NSSet setWithArray:@[
            [NSArray class], [NSMutableArray class], [NSString class]
        ]] forKey:@"4"];
        _serverVersion = [coder decodeIntForKey:@"serverVersion"];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    LookinHierarchyInfo *copy = [LookinHierarchyInfo new];
    copy.displayItems = self.displayItems;
    copy.appInfo = self.appInfo;
    copy.colorAlias = self.colorAlias;
    copy.collapsedClassList = self.collapsedClassList;
    copy.serverVersion = self.serverVersion;
    return copy;
}

@end
