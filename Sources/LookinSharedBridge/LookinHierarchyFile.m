#import "LookinHierarchyFile.h"
#import "LookinHierarchyInfo.h"

@implementation LookinHierarchyFile

+ (BOOL)supportsSecureCoding { return YES; }

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeInt:self.serverVersion forKey:@"serverVersion"];
    [coder encodeObject:self.hierarchyInfo forKey:@"hierarchyInfo"];
    [coder encodeObject:self.soloScreenshots forKey:@"soloScreenshots"];
    [coder encodeObject:self.groupScreenshots forKey:@"groupScreenshots"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [super init]) {
        _serverVersion = [coder decodeIntForKey:@"serverVersion"];
        _hierarchyInfo = [coder decodeObjectOfClass:[LookinHierarchyInfo class] forKey:@"hierarchyInfo"];
        NSSet *dictClasses = [NSSet setWithArray:@[
            [NSDictionary class], [NSNumber class], [NSData class]
        ]];
        _soloScreenshots = [coder decodeObjectOfClasses:dictClasses forKey:@"soloScreenshots"];
        _groupScreenshots = [coder decodeObjectOfClasses:dictClasses forKey:@"groupScreenshots"];
    }
    return self;
}

+ (BOOL)verifyHierarchyFile:(LookinHierarchyFile *)file {
    if (!file) return NO;
    if (!file.hierarchyInfo) return NO;
    if (!file.hierarchyInfo.displayItems) return NO;
    return YES;
}

@end
