#import "bauhausView.h"
#import <QuartzCore/QuartzCore.h>
#import <CoreText/CoreText.h>

@interface bauhausView ()
@property (nonatomic, assign) BOOL nightMode;
@end

@implementation bauhausView

- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview {
    self = [super initWithFrame:frame isPreview:isPreview];
    if (self) {
        [self setAnimationTimeInterval:1.0/60.0];
        _nightMode = YES; // default to night mode
    }
    return self;
}

- (void)setNightMode:(BOOL)enabled {
    _nightMode = enabled;
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)rect {
    CGContextRef ctx = [[NSGraphicsContext currentContext] CGContext];
    CGContextSaveGState(ctx);
    
    // === MODE COLORS ===
    NSColor *bg, *accent, *tickColor, *textColor;
    if (self.nightMode) {
        bg = [NSColor blackColor];
        accent = [NSColor colorWithCalibratedRed:0.0 green:0.73 blue:1.0 alpha:1.0]; // #00BBFF
        tickColor = [accent colorWithAlphaComponent:0.85];
        textColor = accent;
    } else {
        bg = [NSColor colorWithCalibratedRed:0.93 green:0.95 blue:1 alpha:1]; // soft bluish gray
        accent = [NSColor colorWithCalibratedRed:0.09 green:0.14 blue:0.36 alpha:1]; // navy
        tickColor = [accent colorWithAlphaComponent:0.3];
        textColor = accent;
    }
    
    // === BACKGROUND ===
    [bg setFill];
    NSRectFill(rect);
    
    CGFloat width = rect.size.width;
    CGFloat height = rect.size.height;
    CGPoint center = CGPointMake(width/2, height/2);
    CGFloat radius = MIN(width, height) * 0.4;
    
    // === TICKS ===
    for (int i = 0; i < 60; i++) {
        CGFloat angle = M_PI_2 - (i * M_PI / 30.0);
        BOOL isHourMark = (i % 5 == 0);
        
        CGFloat outer = radius;
        CGFloat inner = isHourMark ? radius * 0.88 : radius * 0.95;
        CGContextSaveGState(ctx);
        CGContextTranslateCTM(ctx, center.x, center.y);
        CGContextRotateCTM(ctx, -angle);
        
        if (isHourMark) {
            // pill marker for hour marks
            CGFloat w = radius * 0.035;  // width of the pill
            CGFloat h = radius * 0.12;   // length of the pill
            CGRect r = CGRectMake(-w/2, -outer, w, h);
            
            NSBezierPath *pill = [NSBezierPath bezierPathWithRoundedRect:r xRadius:w/2 yRadius:w/2];
            
            // === Base fill (same as background)
            [bg setFill];
            [pill fill];
            
            // === Outline (accent color)
            [[accent colorWithAlphaComponent:0.3] setStroke]; // reduced opacity
            [pill setLineWidth:1.5];
            [pill stroke];
            
            // === Inner shadow for depth (no gradient)
            NSShadow *innerShadow = [[NSShadow alloc] init];
            innerShadow.shadowColor = [NSColor colorWithWhite:0 alpha:0.35];
            innerShadow.shadowBlurRadius = 3.0;
            innerShadow.shadowOffset = NSMakeSize(0, -1);
            
            // Draw the inner shadow *inside* the pill outline
            [NSGraphicsContext saveGraphicsState];
            NSBezierPath *clipPath = [pill bezierPathByReversingPath]; // invert for inner shadow effect
            [clipPath addClip];
            [innerShadow set];
            [accent setStroke];
            [pill stroke];
            [NSGraphicsContext restoreGraphicsState];
        }
        else {
            // minute tick (simple line)
            CGContextSetLineWidth(ctx, 1.2);
            CGContextSetStrokeColorWithColor(ctx, [tickColor colorWithAlphaComponent:0.3].CGColor);
            CGContextMoveToPoint(ctx, 0, -inner);
            CGContextAddLineToPoint(ctx, 0, -outer);
            CGContextStrokePath(ctx);
        }
        
        CGContextRestoreGState(ctx);
    }

    // === FONTS ===
    NSFont *innerFont = [NSFont fontWithName:@"SF Pro Expanded Regular" size:radius * 0.12]
        ?: [NSFont systemFontOfSize:radius * 0.12 weight:NSFontWeightBold];
    NSFont *outerFont = [NSFont fontWithName:@"SF Pro Expanded Ultralight" size:radius * 0.08]
        ?: [NSFont systemFontOfSize:radius * 0.08];
    
    NSDictionary *innerAttrs = @{
        NSFontAttributeName: innerFont,
        NSForegroundColorAttributeName: textColor
    };
    NSDictionary *outerAttrs = @{
        NSFontAttributeName: outerFont,
        NSForegroundColorAttributeName: [textColor colorWithAlphaComponent:0.7]
    };
    
    // === INNER NUMBERS (1–12) ===
    for (int i = 1; i <= 12; i++) {
        CGFloat angle = M_PI_2 - (i * M_PI / 6.0);
        NSString *text = [NSString stringWithFormat:@"%d", i];
        
        NSAttributedString *str = [[NSAttributedString alloc] initWithString:text attributes:innerAttrs];
        CGSize size = [str size];
        
        CGFloat r = radius * 0.74;
        CGPoint pos = CGPointMake(center.x + r * cos(angle) - size.width / 2,
                                  center.y + r * sin(angle) - size.height / 2);
        [str drawAtPoint:pos];
    }
    
    // === OUTER NUMBERS (05, 10, 15...60) ===
    for (int i = 5; i <= 60; i += 5) {
        CGFloat angle = M_PI_2 - ((i / 5.0) * M_PI / 6.0);
        NSString *text = [NSString stringWithFormat:@"%02d", i % 61];
        
        NSAttributedString *str = [[NSAttributedString alloc] initWithString:text attributes:outerAttrs];
        CGSize size = [str size];
        
        CGFloat r = radius * 1.12;
        CGPoint pos = CGPointMake(center.x + r * cos(angle) - size.width / 2,
                                  center.y + r * sin(angle) - size.height / 2);
        [str drawAtPoint:pos];
    }
    
    // === TIME ===
    NSDate *date = [NSDate date];
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *components = [calendar components:(NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond | NSCalendarUnitNanosecond)
                                               fromDate:date];
    
    CGFloat seconds = components.second + components.nanosecond / 1e9;
    CGFloat minutes = components.minute + seconds / 60.0;
    CGFloat hours = fmod(components.hour, 12) + minutes / 60.0;
    
    CGFloat hourAngle = M_PI_2 - (hours / 12.0) * 2 * M_PI;
    CGFloat minuteAngle = M_PI_2 - (minutes / 60.0) * 2 * M_PI;
    CGFloat secondAngle = M_PI_2 - (seconds / 60.0) * 2 * M_PI;
    
    // === HAND COLORS ===
    NSColor *hourColor = self.nightMode ? [accent colorWithAlphaComponent:0.8] : [NSColor colorWithWhite:1 alpha:0.9];
    NSColor *minuteColor = self.nightMode ? [accent colorWithAlphaComponent:0.85] : [NSColor colorWithWhite:1 alpha:0.9];
    NSColor *secondColor = self.nightMode ? [accent colorWithAlphaComponent:0.6] : [accent colorWithAlphaComponent:0.8];
    
    // === HANDS ===
    [self drawHandInContext:ctx center:center angle:hourAngle
                     length:radius * 0.48 width:7.5
                      color:hourColor background:bg];

    [self drawHandInContext:ctx center:center angle:minuteAngle
                     length:radius * 0.7 width:4.5
                      color:minuteColor background:bg];

    [self drawHandInContext:ctx center:center angle:secondAngle
                     length:radius * 0.82 width:1.8
                      color:secondColor background:bg];

    // === CENTER DOT ===
    CGFloat capRadius = 10;

    // Fill with the background color
    CGContextSetFillColorWithColor(ctx, bg.CGColor);
    CGContextAddEllipseInRect(ctx, CGRectMake(center.x - capRadius, center.y - capRadius, capRadius * 2, capRadius * 2));
    CGContextFillPath(ctx);

    // Outline with the accent color
    CGContextSetStrokeColorWithColor(ctx, accent.CGColor);
    CGContextSetLineWidth(ctx, 2.0);
    CGContextAddEllipseInRect(ctx, CGRectMake(center.x - capRadius, center.y - capRadius, capRadius * 2, capRadius * 2));
    CGContextStrokePath(ctx);

}

- (void)drawHandInContext:(CGContextRef)ctx
                   center:(CGPoint)center
                    angle:(CGFloat)angle
                   length:(CGFloat)length
                    width:(CGFloat)width
                    color:(NSColor*)color
               background:(NSColor*)bgColor
{
    CGContextSaveGState(ctx);
    CGContextTranslateCTM(ctx, center.x, center.y);
    CGContextRotateCTM(ctx, -angle);
    
    // ==== OUTER GLOW ====
    // Soft glow in the hand's color
    CGContextSetShadowWithColor(ctx,
                                CGSizeZero,
                                width * 1.8, // glow radius
                                [color colorWithAlphaComponent:0.6].CGColor);
    
    CGContextSetLineCap(ctx, kCGLineCapRound);
    CGContextSetStrokeColorWithColor(ctx, color.CGColor);
    CGContextSetLineWidth(ctx, width);
    CGContextMoveToPoint(ctx, 0, 0);
    CGContextAddLineToPoint(ctx, 0, -length);
    CGContextStrokePath(ctx);
    
    // ==== RESET SHADOW ====
    CGContextSetShadowWithColor(ctx, CGSizeZero, 0, NULL);
    
    // ==== BACKGROUND OUTLINE ====
    // Outline to visually separate from background (like a rim light)
    CGContextSetStrokeColorWithColor(ctx, bgColor.CGColor);
    CGContextSetLineWidth(ctx, width + 2.4); // slightly thicker outline
    CGContextMoveToPoint(ctx, 0, 0);
    CGContextAddLineToPoint(ctx, 0, -length);
    CGContextStrokePath(ctx);
    
    // ==== RE-PAINT MAIN BODY ====
    CGContextSetStrokeColorWithColor(ctx, color.CGColor);
    CGContextSetLineWidth(ctx, width);
    CGContextMoveToPoint(ctx, 0, 0);
    CGContextAddLineToPoint(ctx, 0, -length);
    CGContextStrokePath(ctx);
    
    // ==== INNER SHADOW ====
    // Simulate inner bevel look
    CGContextSaveGState(ctx);
    CGContextClipToRect(ctx, CGRectMake(-width, -length, width * 2, length)); // clip to hand area
    
    CGContextSetShadowWithColor(ctx,
                                CGSizeMake(0, -1.2),
                                2.0,
                                [NSColor colorWithWhite:0 alpha:0.25].CGColor);
    
    CGContextSetStrokeColorWithColor(ctx, [color colorWithAlphaComponent:0.9].CGColor);
    CGContextSetLineWidth(ctx, width * 0.8);
    CGContextMoveToPoint(ctx, 0, 0);
    CGContextAddLineToPoint(ctx, 0, -length * 0.98);
    CGContextStrokePath(ctx);
    
    CGContextRestoreGState(ctx);
    
    // ==== INNER GLOW STRIP (like Apple Watch) ====
    CGContextSetStrokeColorWithColor(ctx, [NSColor colorWithWhite:1 alpha:0.18].CGColor);
    CGContextSetLineWidth(ctx, width * 0.3);
    CGContextMoveToPoint(ctx, width * 0.35, 0);
    CGContextAddLineToPoint(ctx, width * 0.35, -length * 0.95);
    CGContextStrokePath(ctx);
    
    CGContextRestoreGState(ctx);
}


- (void)animateOneFrame {
    [self setNeedsDisplay:YES];
}

@end
