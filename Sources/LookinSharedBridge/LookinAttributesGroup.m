#import "LookinAttributesGroup.h"
#import "LookinAttributesSection.h"

@implementation LookinAttributesGroup

+ (BOOL)supportsSecureCoding { return YES; }

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.userCustomTitle forKey:@"userCustomTitle"];
    [coder encodeObject:self.identifier forKey:@"identifier"];
    [coder encodeObject:self.attrSections forKey:@"attrSections"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [super init]) {
        _userCustomTitle = [coder decodeObjectOfClass:[NSString class] forKey:@"userCustomTitle"];
        _identifier = [coder decodeObjectOfClass:[NSString class] forKey:@"identifier"];
        NSSet *classes = [NSSet setWithArray:@[[NSArray class], [NSMutableArray class], [LookinAttributesSection class]]];
        _attrSections = [coder decodeObjectOfClasses:classes forKey:@"attrSections"];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    LookinAttributesGroup *copy = [LookinAttributesGroup new];
    copy.userCustomTitle = self.userCustomTitle;
    copy.identifier = self.identifier;
    copy.attrSections = self.attrSections;
    return copy;
}

- (NSString *)uniqueKey {
    return self.identifier ?: self.userCustomTitle ?: @"";
}

- (BOOL)isUserCustom {
    return self.userCustomTitle.length > 0;
}

@end
