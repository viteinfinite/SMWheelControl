//
//  SMWheelControl.m
//  RotaryWheelProject
//
//  Created by cesarerocchi on 2/10/12.
//  Copyright (c) 2012 studiomagnolia.com. All rights reserved.


#import "SMWheelControl.h"
#import <QuartzCore/QuartzCore.h>
#import "SMWheelControlDataSource.h"

@interface SMWheelControl ()

@property (nonatomic, strong) UIView *sliceContainer;
@property (nonatomic, assign) int selectedIndex;

@end

@implementation SMWheelControl {
    BOOL _decelerating;
    CGFloat _animatingVelocity;
    
    CADisplayLink *_decelerationDisplayLink;
    CADisplayLink *_inertiaDisplayLink;
    
    CFTimeInterval _startTouchTime;
    CFTimeInterval _endTouchTime;

    CGFloat _startTouchAngle;
    CGFloat _previousTouchAngle;
    CGFloat _currentTouchAngle;
    
    CGFloat _snappingTargetAngle;
    CGFloat _snappingStep;
}

- (id)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame])) {
		
        self.selectedIndex = 0;
		[self drawWheel];
        
	}
    return self;
}

- (void)clearWheel
{
    for (UIView *subview in self.sliceContainer.subviews) {
        [subview removeFromSuperview];
    }
}

- (void)drawWheel
{
    self.sliceContainer = [[UIView alloc] initWithFrame:self.bounds];
    NSUInteger numberOfSlices = [self.dataSource numberOfSlicesInWheel:self];

    CGFloat angleSize = 2 * M_PI / numberOfSlices;
    
    for (int i = 0; i < numberOfSlices; i++) {
        
        UIView *sliceView = [self.dataSource wheel:self viewForSliceAtIndex:i];
        sliceView.layer.anchorPoint = CGPointMake(1.0f, 0.5f);
        sliceView.layer.position = CGPointMake(self.sliceContainer.bounds.size.width / 2.0 - self.sliceContainer.frame.origin.x,
                                        self.sliceContainer.bounds.size.height / 2.0 - self.sliceContainer.frame.origin.y);
        sliceView.transform = CGAffineTransformMakeRotation(angleSize * i);

        [self.sliceContainer addSubview:sliceView];
    }
    
    self.sliceContainer.userInteractionEnabled = NO;
    [self addSubview:self.sliceContainer];
}


- (void)didEndRotationOnSliceAtIndex:(NSUInteger)index
{
    self.selectedIndex = index;
    if ([self.delegate respondsToSelector:@selector(wheelDidEndDecelrating:)]) {
        [self.delegate wheelDidEndDecelerating:self];
    }
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}


#pragma mark - Touches

- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    if (_decelerating) {
        [self.sliceContainer.layer removeAllAnimations];
        [self endDecelerationAvoidingSnap:NO];
    }

    CGPoint touchPoint = [touch locationInView:self];
    float dist = [self distanceFromCenter:touchPoint];
    
    if (dist < kMinDistanceFromCenter)
    {
        return NO;
    }

    _startTouchTime = _endTouchTime = CACurrentMediaTime();
    
    float dx = touchPoint.x - self.sliceContainer.center.x;
	float dy = touchPoint.y - self.sliceContainer.center.y;

	_startTouchAngle = _currentTouchAngle = _previousTouchAngle = atan2f(dy, dx);
    
    return YES;
}


- (BOOL)continueTrackingWithTouch:(UITouch*)touch withEvent:(UIEvent*)event
{
    CGPoint pt = [touch locationInView:self];

    _startTouchTime = _endTouchTime;
    _endTouchTime = CACurrentMediaTime();
    
    float dist = [self distanceFromCenter:pt];
    
    if (dist < kMinDistanceFromCenter) {
        // Drag path too close to the center
        return NO;        
    }

	float dx = pt.x - self.sliceContainer.center.x;
	float dy = pt.y - self.sliceContainer.center.y;

    _previousTouchAngle = _currentTouchAngle;
	_currentTouchAngle = atan2f(dy, dx);

    CGFloat angleDelta = _currentTouchAngle - _previousTouchAngle;

    self.sliceContainer.transform = CGAffineTransformRotate(self.sliceContainer.transform, angleDelta);
    
    if ([self.delegate respondsToSelector:@selector(wheel:didRotateByAngle:)]) {
        [self.delegate wheel:self didRotateByAngle:(angleDelta)];
    }
    
    return YES;
}


- (void)endTrackingWithTouch:(UITouch*)touch withEvent:(UIEvent*)event
{
    [self beginDeceleration];
}


#pragma mark - Inertia

- (void)beginDeceleration
{
    _animatingVelocity = [self velocity];
    
    if (_animatingVelocity != 0) {
        _decelerating = YES;
        [_decelerationDisplayLink invalidate];
        _decelerationDisplayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(decelerationStep)];
        _decelerationDisplayLink.frameInterval = 1;
        [_decelerationDisplayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    } else {
        [self snapToNearestSlice];
    }
}


- (void)decelerationStep
{
    CGFloat newVelocity = _animatingVelocity * kDecelerationRate;
    
    CGFloat angle = _animatingVelocity / 60.0;
    
    if (newVelocity <= kMinDeceleration && newVelocity >= -kMinDeceleration) {
        [self endDecelerationAvoidingSnap:NO];
    } else {
        _animatingVelocity = newVelocity;
        
        self.sliceContainer.transform = CGAffineTransformRotate(self.sliceContainer.transform, -angle);
        
        if ([self.delegate respondsToSelector:@selector(wheel:didRotateByAngle:)]) {
            [self.delegate wheel:self didRotateByAngle:-angle];
        }
    }
}


- (void)endDecelerationAvoidingSnap:(BOOL)avoidSnap
{
    [_decelerationDisplayLink invalidate];
    _decelerating = NO;
    
    if (!avoidSnap) {
        [self snapToNearestSlice];
    }    
}


#pragma mark - Snapping

- (void)snapToNearestSlice
{
    CGFloat currentAngle = atan2f(self.sliceContainer.transform.b, self.sliceContainer.transform.a);
    
    int numberOfSlices = [self.dataSource numberOfSlicesInWheel:self];
    CGFloat radiansPerSlice = 2.0 * M_PI / numberOfSlices;
    int closestSlice = round(currentAngle / radiansPerSlice);
    _snappingTargetAngle = (CGFloat)closestSlice * radiansPerSlice;
    
    if (currentAngle != _snappingTargetAngle) {
        _snappingStep = -(currentAngle - _snappingTargetAngle) / 10.0;
    } else {
        return;
    }
    
    _animatingVelocity = [self velocity];
    
    if (_animatingVelocity != 0) {
        [_inertiaDisplayLink invalidate];
        _inertiaDisplayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(snappingStep)];
        _inertiaDisplayLink.frameInterval = 1;
        [_inertiaDisplayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    }
}

- (void)snappingStep
{
    CGFloat currentAngle = atan2f(self.sliceContainer.transform.b, self.sliceContainer.transform.a);
    
    if (fabsf(currentAngle - _snappingTargetAngle) <= 0.001) {
        [self endSnapping];
    } else {
        currentAngle += _snappingStep;
        self.sliceContainer.transform = CGAffineTransformMakeRotation(currentAngle);
        
        if ([self.delegate respondsToSelector:@selector(wheel:didRotateByAngle:)]) {
            [self.delegate wheel:self didRotateByAngle:_snappingStep];
        }
    }
}

- (void)endSnapping
{
    [_inertiaDisplayLink invalidate];
}


#pragma mark - Accessory methods

- (CGFloat)velocity
{
    CGFloat velocity = 0.0;

    if (_startTouchTime != _endTouchTime) {
        velocity = (_previousTouchAngle - _currentTouchAngle) / (_endTouchTime - _startTouchTime);
    }

    if (velocity > kMaxVelocity) {
        velocity = kMaxVelocity;
    } else if (velocity < -kMaxVelocity) {
        velocity = -kMaxVelocity;
    }

    return velocity;
}


- (float)distanceFromCenter:(CGPoint)point
{
    CGPoint center = CGPointMake(self.bounds.size.width/2.0f, self.bounds.size.height/2.0f);
    float dx = point.x - center.x;
    float dy = point.y - center.y;
    return sqrt(dx * dx + dy * dy);
}


- (void)reloadData
{
    [self clearWheel];
    [self drawWheel];
}



@end
