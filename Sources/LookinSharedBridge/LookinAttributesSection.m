#import "LookinAttributesSection.h"
#import "LookinAttribute.h"

@implementation LookinAttributesSection

+ (BOOL)supportsSecureCoding { return YES; }

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.identifier forKey:@"identifier"];
    [coder encodeObject:self.attributes forKey:@"attributes"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [super init]) {
        _identifier = [coder decodeObjectOfClass:[NSString class] forKey:@"identifier"];
        NSSet *classes = [NSSet setWithArray:@[[NSArray class], [LookinAttribute class]]];
        _attributes = [coder decodeObjectOfClasses:classes forKey:@"attributes"];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    LookinAttributesSection *copy = [LookinAttributesSection new];
    copy.identifier = self.identifier;
    copy.attributes = self.attributes;
    return copy;
}

@end
