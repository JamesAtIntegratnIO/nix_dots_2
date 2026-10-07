// The cyberdeck screen saver: the wallpaper renders in the bundle's Resources,
// crossfading from one to the next while each drifts slowly, so nothing sits
// on the same pixels for long. The image is picked from the clock, as in
// ./wallpaper.js, so every display shows the same one.
#import <QuartzCore/QuartzCore.h>
#import <ScreenSaver/ScreenSaver.h>

static const NSTimeInterval kHold = 40; // seconds per image
static const NSTimeInterval kFade = 3;
static const CGFloat kDrift = 1.06; // scale reached over one hold

@interface CyberdeckView : ScreenSaverView
@end

@implementation CyberdeckView {
  NSArray<NSURL *> *_images;
  CALayer *_front;
  NSTimer *_timer;
}

- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview {
  if ((self = [super initWithFrame:frame isPreview:isPreview])) {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    _images = [[bundle URLsForResourcesWithExtension:@"png" subdirectory:nil]
        sortedArrayUsingComparator:^(NSURL *a, NSURL *b) {
          return [a.lastPathComponent compare:b.lastPathComponent];
        }];

    self.wantsLayer = YES;
    self.layer.backgroundColor = CGColorGetConstantColor(kCGColorBlack);
    self.layer.masksToBounds = YES;

    // legacyScreenSaver keeps the saver's process and its timers alive after
    // the saver is dismissed, and starts another on the next activation.
    if (!isPreview) {
      [NSDistributedNotificationCenter.defaultCenter addObserver:self
                                                        selector:@selector(willStop:)
                                                            name:@"com.apple.screensaver.willstop"
                                                          object:nil];
    }
  }
  return self;
}

- (void)willStop:(NSNotification *)note {
  exit(0);
}

- (void)startAnimation {
  [super startAnimation];
  if (_timer || _images.count == 0) return;
  [self showNext];
  // Fire on the clock's kHold boundaries so the displays change together.
  NSTimeInterval now = NSDate.date.timeIntervalSince1970;
  NSDate *boundary = [NSDate dateWithTimeIntervalSince1970:(floor(now / kHold) + 1) * kHold];
  _timer = [[NSTimer alloc] initWithFireDate:boundary
                                    interval:kHold
                                      target:self
                                    selector:@selector(showNext)
                                    userInfo:nil
                                     repeats:YES];
  [NSRunLoop.mainRunLoop addTimer:_timer forMode:NSRunLoopCommonModes];
}

- (void)stopAnimation {
  [_timer invalidate];
  _timer = nil;
  [super stopAnimation];
}

- (void)showNext {
  NSUInteger turn = (NSUInteger)(NSDate.date.timeIntervalSince1970 / kHold);
  NSImage *image = [[NSImage alloc] initWithContentsOfURL:_images[turn % _images.count]];
  if (!image) return;

  CALayer *layer = [CALayer layer];
  layer.frame = self.layer.bounds;
  layer.autoresizingMask = kCALayerWidthSizable | kCALayerHeightSizable;
  layer.contentsGravity = kCAGravityResizeAspectFill;
  layer.contents = image;

  CABasicAnimation *drift = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
  drift.fromValue = @1.0;
  drift.toValue = @(kDrift);
  drift.duration = kHold + kFade;
  drift.fillMode = kCAFillModeForwards;
  drift.removedOnCompletion = NO;
  [layer addAnimation:drift forKey:@"drift"];

  CABasicAnimation *fade = [CABasicAnimation animationWithKeyPath:@"opacity"];
  fade.fromValue = @0.0;
  fade.toValue = @1.0;
  fade.duration = kFade;
  [layer addAnimation:fade forKey:@"fade"];

  [self.layer addSublayer:layer];
  CALayer *old = _front;
  _front = layer;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kFade * NSEC_PER_SEC)),
                 dispatch_get_main_queue(), ^{
                   [old removeFromSuperlayer];
                 });
}

- (BOOL)hasConfigureSheet {
  return NO;
}

@end
