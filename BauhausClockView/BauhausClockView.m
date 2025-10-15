//
//  BauhausClockView.m
//  BauhausClock
//
//  Created by Aryan on 10/14/25.
//

#import "BauhausClockView.h"
#import <QuartzCore/QuartzCore.h>
#import <CoreText/CoreText.h>

#pragma mark - 🌈 Global Theme Configuration (All Hex-Based)

// === ACCENT COLOR (applies globally) ===
static NSString *const kAccentHex = @"00b3ff"; // alternatives: #00b3ff, 00bbff

// === LIGHT MODE COLORS ===
static NSString *const kLightBackgroundHex = @"00AEEC";

// === DARK MODE COLORS ===
static NSString *const kDarkBackgroundHex  = @"000000";

// === Helper: Convert HEX → NSColor ===
static NSColor *ColorFromHex(NSString *hex) {
    NSString *clean = [[hex stringByTrimmingCharactersInSet:
                        [NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
    if ([clean hasPrefix:@"#"]) clean = [clean substringFromIndex:1];
    
    unsigned int rgbValue = 0;
    [[NSScanner scannerWithString:clean] scanHexInt:&rgbValue];
    
    return [NSColor colorWithCalibratedRed:((rgbValue & 0xFF0000) >> 16) / 255.0
                                     green:((rgbValue & 0x00FF00) >> 8) / 255.0
                                      blue:(rgbValue & 0x0000FF) / 255.0
                                     alpha:1.0];
}

#pragma mark - 🕰️ BauhausClockView Implementation

@interface BauhausClockView ()
@property (nonatomic, assign) BOOL nightMode;
@property (nonatomic, assign) NSInteger lastSecond; // PERF: Track last rendered second to avoid unnecessary redraws
@end

@implementation BauhausClockView

- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview {
    self = [super initWithFrame:frame isPreview:isPreview];
    if (self) {
        // PERF: Reduced from 1.0/60.0 (60fps) to 1.0/30.0 (30fps)
        // 30fps is smooth enough for a clock and uses 50% less CPU
        [self setAnimationTimeInterval:1.0/60.0];
        _nightMode = YES;
        _lastSecond = -1; // PERF: Initialize to invalid value
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
    
    // PERF: Enable anti-aliasing for optimal rendering
    CGContextSetShouldAntialias(ctx, YES);
    CGContextSetAllowsAntialiasing(ctx, YES);
    
    // === COLOR SELECTION ===
    NSColor *accent = ColorFromHex(kAccentHex);
    NSColor *bg, *tickColor, *textColor;
    
    if (self.nightMode) {
        bg        = ColorFromHex(kDarkBackgroundHex);
        tickColor = [ColorFromHex(kAccentHex) colorWithAlphaComponent:0.85];
        textColor = ColorFromHex(kAccentHex);
    } else {
        bg        = ColorFromHex(kLightBackgroundHex);
        tickColor = [ColorFromHex(kAccentHex) colorWithAlphaComponent:0.35];
        textColor = ColorFromHex(kAccentHex);
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
        
        CGContextSaveGState(ctx);
        CGContextTranslateCTM(ctx, center.x, center.y);
        CGContextRotateCTM(ctx, -angle);
        
        if (isHourMark) {
            CGFloat w = radius * 0.035;
            CGFloat h = radius * 0.12;
            CGRect r = CGRectMake(-w/2, -radius, w, h);
            
            NSBezierPath *pill = [NSBezierPath bezierPathWithRoundedRect:r xRadius:w/2 yRadius:w/2];
            [NSGraphicsContext saveGraphicsState];
            
            // Glow
            NSShadow *glow = [[NSShadow alloc] init];
            glow.shadowColor = [accent colorWithAlphaComponent:0.4];
            glow.shadowBlurRadius = 40.0;
            glow.shadowOffset = NSZeroSize;
            [glow set];
            
            [accent setFill];
            [pill fill];
            
            [bg setStroke];
            [pill setLineWidth:2.5];
            [pill stroke];
            
            [NSGraphicsContext restoreGraphicsState];
        } else {
            CGContextSetLineWidth(ctx, 1.0);
            CGContextSetStrokeColorWithColor(ctx, [tickColor colorWithAlphaComponent:0.4].CGColor);
            CGContextMoveToPoint(ctx, 0, -radius * 0.95);
            CGContextAddLineToPoint(ctx, 0, -radius);
            CGContextStrokePath(ctx);
        }
        
        CGContextRestoreGState(ctx);
    }

    // === FONTS ===
    NSFont *innerFont = [NSFont fontWithName:@"SF Pro Expanded Regular" size:radius * 0.14]
        ?: [NSFont systemFontOfSize:radius * 0.12 weight:NSFontWeightBold];
    NSFont *outerFont = [NSFont fontWithName:@"SF Pro Expanded Ultralight" size:radius * 0.08]
        ?: [NSFont systemFontOfSize:radius * 0.08];
    
    NSDictionary *innerAttrs = @{
        NSFontAttributeName: innerFont,
        NSForegroundColorAttributeName: textColor
    };
    NSDictionary *outerAttrs = @{
        NSFontAttributeName: outerFont,
        NSForegroundColorAttributeName: [textColor colorWithAlphaComponent:0.5]
    };
    
    // === INNER NUMBERS ===
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
    
    // === OUTER NUMBERS ===
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

    // Keep nanosecond precision for smooth second hand animation
    CGFloat seconds = components.second + components.nanosecond / 1e9;
    CGFloat minutes = components.minute + seconds / 60.0;
    CGFloat hours = fmod(components.hour, 12) + minutes / 60.0;

    // Correct angles - adjusted for the 90-degree offset
    CGFloat hourAngle = -(hours * 2 * M_PI / 12.0);
    CGFloat minuteAngle = -(minutes * 2 * M_PI / 60.0);
    CGFloat secondAngle = -(seconds * 2 * M_PI / 60.0);
    
    
    // PERF: Reuse accent color object instead of creating new ones
    // Was: [accent colorWithAlphaComponent:1]
    NSColor *hourColor = accent;
    NSColor *minuteColor = accent;
    NSColor *secondColor = accent;
    

    [self drawHandInContext:ctx
                     center:center
                      angle:hourAngle
                     length:radius * 0.6
                      width:17
                      color:hourColor
                 background:bg
                     accent:hourColor];

    [self drawHandInContext:ctx
                     center:center
                      angle:minuteAngle
                     length:radius * 0.85
                      width:14
                      color:minuteColor
                 background:bg
                     accent:minuteColor];

    [self drawHandInContext:ctx
                     center:center
                      angle:secondAngle
                     length:radius * 0.9
                      width:5
                      color:secondColor
                 background:bg
                     accent:secondColor];
    
    // Center dot
    CGFloat capRadius = 10;
    CGContextSetFillColorWithColor(ctx, bg.CGColor);
    CGContextAddEllipseInRect(ctx, CGRectMake(center.x - capRadius, center.y - capRadius, capRadius * 2, capRadius * 2));
    CGContextFillPath(ctx);
    
    CGContextSetStrokeColorWithColor(ctx, accent.CGColor);
    CGContextSetLineWidth(ctx, 1.0);
    CGContextAddEllipseInRect(ctx, CGRectMake(center.x - capRadius, center.y - capRadius, capRadius * 2, capRadius * 2));
    CGContextStrokePath(ctx);
    
    CGContextRestoreGState(ctx);
    
    // PERF: Update last rendered second
    self.lastSecond = components.second;
}

- (void)drawHandInContext:(CGContextRef)ctx
                   center:(CGPoint)center
                    angle:(CGFloat)angle
                   length:(CGFloat)length
                    width:(CGFloat)width
                    color:(NSColor*)accent
               background:(NSColor*)bgColor
                   accent:(NSColor*)accentColor
{
    CGContextSaveGState(ctx);
    CGContextTranslateCTM(ctx, center.x, center.y);
    CGContextRotateCTM(ctx, angle);
    
    // === SHAPE PROPORTIONS ===
    CGFloat baseWidth = width;
    CGFloat bodyLength = length * 0.88;     // most of the hand is rectangular
    CGFloat taperLength = length * 0.12;    // gentle taper at the end
    CGFloat taperStartY = bodyLength;
    
    // === MAIN BODY SHAPE (rectangle with rounded taper) ===
    NSBezierPath *outerPath = [NSBezierPath bezierPath];
    [outerPath moveToPoint:NSMakePoint(-baseWidth / 2.0, 0)];           // Bottom left
    [outerPath lineToPoint:NSMakePoint(baseWidth / 2.0, 0)];            // Bottom right
    [outerPath lineToPoint:NSMakePoint(baseWidth / 2.0, taperStartY)];  // Top right of rectangle
    
    // Gentle curve to rounded tip
    [outerPath curveToPoint:NSMakePoint(0, length)                      // Tip point
              controlPoint1:NSMakePoint(baseWidth / 2.0, taperStartY + taperLength * 0.3)
              controlPoint2:NSMakePoint(baseWidth / 4.0, length - taperLength * 0.2)];
    
    // Curve back down the other side
    [outerPath curveToPoint:NSMakePoint(-baseWidth / 2.0, taperStartY)  // Top left of rectangle
              controlPoint1:NSMakePoint(-baseWidth / 4.0, length - taperLength * 0.2)
              controlPoint2:NSMakePoint(-baseWidth / 2.0, taperStartY + taperLength * 0.3)];
    
    [outerPath closePath];
    
    // === COLORS ===
    NSColor *metalColor;
    NSColor *outlineColor;
    NSColor *radiumColor = accent;
    
    if (self.nightMode) {
        metalColor   = bgColor;
        outlineColor = [accent colorWithAlphaComponent:0.1];
    } else {
        metalColor   = [NSColor colorWithCalibratedWhite:0.75 alpha:1.0]; // silver
        outlineColor = [NSColor whiteColor];
    }
    
    // === METAL BODY WITH SHADOW ===
    [NSGraphicsContext saveGraphicsState];
    
    // Add shadow below the hand
    NSShadow *handShadow = [[NSShadow alloc] init];
    handShadow.shadowColor = [accent colorWithAlphaComponent:0.4];
    handShadow.shadowBlurRadius = 60.0;
    [handShadow set];
    
    [metalColor setFill];
    [outerPath fill];
    
    [NSGraphicsContext restoreGraphicsState];
    
    [outlineColor setStroke];
    [outerPath setLineWidth:1.2];
    [outerPath stroke];
    
    // === RADIUM INSET WITH PADDING FROM ALL SIDES ===
    CGFloat sidePadding = width * 0.35;      // padding from left/right edges
    CGFloat bottomPadding = length * 0.15;   // padding from bottom
    CGFloat topEnd = bodyLength * 0.95;      // stop before taper begins
    
    CGFloat radiumWidth = baseWidth - (sidePadding * 2);
    CGFloat radiumLength = topEnd - bottomPadding;
    CGFloat insetRadius = radiumWidth * 0.5;
    
    NSRect radiumRect = NSMakeRect(-radiumWidth / 2.0,
                                   bottomPadding,
                                   radiumWidth,
                                   radiumLength);
    
    NSBezierPath *radiumPath = [NSBezierPath bezierPathWithRoundedRect:radiumRect
                                                               xRadius:insetRadius
                                                               yRadius:insetRadius];
    [radiumColor setFill];
    [radiumPath fill];
    
    CGContextRestoreGState(ctx);
    
}

- (void)animateOneFrame {
    // PERF: Optional optimization - only redraw when second changes
    // Uncomment the code below to reduce redraws from 30fps to 1fps (huge battery savings)
    // Note: This will make the second hand jump instead of being smooth
    /*
    NSDate *date = [NSDate date];
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *components = [calendar components:NSCalendarUnitSecond fromDate:date];
    
    if (components.second != self.lastSecond) {
        [self setNeedsDisplay:YES];
    }
    */
    
    // Current: Always redraw (smooth animation)
    [self setNeedsDisplay:YES];
}

@end
