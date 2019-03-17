//
//  DetailScrubber.swift
//
//  Created by Hirohito Kato on 2017/10/17.
//  Copyright (c) 2017 Hirohito Kato. MIT License.
//
//  * This class is strongly inspired by Ole Begemann's OBSlider
//    and Jonas Gessner's JGDetailScrubber.
//    https://github.com/ole/OBSlider
//    https://github.com/JonasGessner/JGDetailScrubber

import UIKit

@objc public protocol DetailScrubberDelegate {
    /**
     (Optional)
     Returns the scrubbing speeds as value for the Y-offsets as keys.

     ```
     // default value
     scrubbingSpeeds = [   //  Y-offset :  speed
         0.0    : 1.0,     //   0- 49pt ⇒ 100%
         50.0   : 0.5,     //  50- 99pt ⇒  50%
         100.0  : 0.25,    // 100-149pt ⇒  25%
         150.0  : 0.1]     // 150-  *pt ⇒  10%
     ```
     
     - parameter scrubber: An object representing the scurbber requesting this information.
     if returns nil, then use the above default value.
     - returns: the array of dictionary `[CGFloat: Float]`.
     */
    @objc optional func scrubbingSpeedsOfDetailScrubber(_ scrubber: DetailScrubber) -> [CGFloat:Float]?

    /**
     (Optional)
     Tells the delegate that the current scrubbing speed has been changed.
     */
    @objc optional func scrubber(_ scrubber: DetailScrubber,
                  didChangeScrubbingSpeed speed: Float, yoffset: CGFloat)

    /**
     (Optional)
     Tells the delegate that the slider has detected a long press gesture.
     */
    @objc optional func scrubber(_ scrubber: DetailScrubber,
                                 didDetectLongPress inLongPressing: Bool)
}

// MARK: -
open class DetailScrubber: UISlider {
    
    /**
     The delegate of scrubber object, confoms to `DetailScrubberDelegate` protocol.
     */
    public var delegate:DetailScrubberDelegate?
    
    /**
     Holds the scrubbing speeds as value for the Y-Offsets as keys.
     ```
     scrubber.scrubbingSpeeds = [//  Y-offset :  speed
         0.0    : 1.0,           //   0- 49pt ⇒ 100%
         50.0   : 0.5,           //  50- 99pt ⇒  50%
         100.0  : 0.25,          // 100-149pt ⇒  25%
         150.0  : 0.1]           // 150-  *pt ⇒  10%
     ```
     */
    public var scrubbingSpeeds: [CGFloat:Float] =
        [0.0:1.0, 50.0:0.5, 100.0:0.25, 150.0:0.1] {
        didSet {
            if scrubbingSpeeds[0.0] != 1.0 {
                scrubbingSpeeds[0.0] = 1.0
            }
        }
    }
    
    /**
     Current scrubbing speed. If `UIControl`'s `tracking` is `NO`,
     the return value will be `1.0`
     */
    public var currentSpeed: Float {
        get { return _scrubbingSpeed.speed }
    }
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        setupLongPressGesture()
    }
    
    required public init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
        
        if let speeds: AnyObject = decoder.decodeObject(forKey: "scrubbingSpeeds") as AnyObject? {
            scrubbingSpeeds = speeds as! [CGFloat : Float]
        }
        
        setupLongPressGesture()
    }
    
    open override func encode(with encoder: NSCoder) {
        super.encode(with: encoder)
        encoder.encode(scrubbingSpeeds, forKey: "scrubbingSpeeds")
    }
    
    // MARK: - UISlider Getters & Setters
    open override func setValue(_ value: Float, animated: Bool) {
        _realPositionValue = value
        super.setValue(value, animated: animated)
    }
    
    // MARK: Privates
    private var _scrubbingSpeed: (yoffset: CGFloat, speed: Float) = (0.0, 0.0) {
        didSet {
            if _scrubbingSpeed.yoffset != oldValue.yoffset {
                // announce a change.
                delegate?.scrubber?(self,
                                    didChangeScrubbingSpeed: _scrubbingSpeed.speed,
                                    yoffset: _scrubbingSpeed.yoffset)
            }
        }
    }
    private var _realPositionValue: Float = 1.0
    private var _beganTrackingLocation = CGPoint.zero
    
    private func _lowerScrubbingSpeed(_ scrubbingSpeed:[CGFloat:Float], offset: CGFloat)
        -> (yoffset: CGFloat, speed: Float)
    {
        var prevSpeed = scrubbingSpeeds.min(){ $0.0 < $1.0 }!
        let sorted = scrubbingSpeeds.sorted(){ $0.0 < $1.0 }
        
        for keyvalue in sorted {
            if offset < keyvalue.0 {
                let speed: (yoffset: CGFloat, speed: Float) = (prevSpeed.0, prevSpeed.1)
                return speed
            }
            prevSpeed = keyvalue
        }
        let speed: (yoffset: CGFloat, speed: Float) = (prevSpeed.0, prevSpeed.1)
        return speed
    }
    
    private var _longPressTimer: Timer?
    private var _longPressStartPosition: CGPoint = CGPoint.zero
    private var _longPressed: Bool = false {
        didSet {
            if (oldValue != _longPressed) {
                // notify the event
                delegate?.scrubber?(self, didDetectLongPress: _longPressed)
            }
        }
    }
}

// MARK: - Touch handling
private typealias TrackingTouches = DetailScrubber
extension TrackingTouches {
    
    open override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        
        let beginTracking = super.beginTracking(touch, with: event)
        if beginTracking {
            // query the default speeds to its delegate
            if let speeds = delegate?.scrubbingSpeedsOfDetailScrubber?(self) {
                scrubbingSpeeds = speeds
            }
            
            let thumbRect = self.thumbRect(forBounds: bounds,
                                           trackRect: trackRect(forBounds: bounds), value: value)
            _beganTrackingLocation = CGPoint(x: thumbRect.origin.x + thumbRect.size.width / 2.0,
                                             y: thumbRect.origin.y + thumbRect.size.height / 2.0)
            _realPositionValue = value
            
            startLongPressing(touch)
        }
        return beginTracking
    }
    
    open override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        if !isTracking {
            return false
        }
        
        let prevLocation = touch.previousLocation(in: self)
        let currentLocation = touch.location(in: self)
        let trackingOffset = currentLocation.x - prevLocation.x
        let vertOffset = abs(currentLocation.y - _beganTrackingLocation.y)
        
        _scrubbingSpeed = _lowerScrubbingSpeed(scrubbingSpeeds, offset: vertOffset)
        
        let trackRect = self.trackRect(forBounds: bounds)
        _realPositionValue = _realPositionValue + (maximumValue - minimumValue)
            * Float(trackingOffset / trackRect.size.width)
        
        let valueAdjustment = _scrubbingSpeed.speed * (maximumValue - minimumValue)
            * Float(trackingOffset / trackRect.size.width)
        let thumbAdjustment: Float
        if (_beganTrackingLocation.y < currentLocation.y && currentLocation.y < prevLocation.y) ||
            (_beganTrackingLocation.y > currentLocation.y && currentLocation.y > prevLocation.y) {
            thumbAdjustment = (_realPositionValue - value)
                / Float(1 + abs(currentLocation.y - _beganTrackingLocation.y))
        } else {
            thumbAdjustment = 0.0
        }
        value += Float(valueAdjustment + thumbAdjustment)
        
        if isContinuous {
            sendActions(for: .valueChanged)
        }
        
        continueLongPressing(touch)
        
        return isTracking
    }
    
    open override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        if !isTracking {
            return
        }
        
        endLongPressing(touch!)
        
        // Reset speed
        _scrubbingSpeed = (0.0, scrubbingSpeeds[0.0]!)
        sendActions(for: .valueChanged);
    }
}

// MARK: Long press gesture
private typealias LongPressGesture = DetailScrubber
private extension LongPressGesture {
    func setupLongPressGesture() {
    }
    func startLongPressing(_ touch: UITouch) {
        _longPressed = false
        _longPressTimer = Timer.scheduledTimer(timeInterval: 1.0,
                                               target: self,
                                               selector: #selector(DetailScrubber.longPressed(_:)),
                                               userInfo: nil,
                                               repeats: false)
        _longPressStartPosition = touch.location(in: self)
    }
    func continueLongPressing(_ touch: UITouch) {
        guard let _ = _longPressTimer else {
            return
        }
        
        let currentLocation = touch.location(in: self)
        let length = _longPressStartPosition.length(other: currentLocation)
            * _scrubbingSpeed.speed.cgfloat
        if  length > 50 && !_longPressed {
            // cancel current timer/state
            endLongPressing(touch)
            startLongPressing(touch)
        }
    }
    func endLongPressing(_ touch: UITouch) {
        _longPressTimer?.invalidate()
        _longPressTimer = nil
        _longPressStartPosition = CGPoint.zero
        _longPressed = false
    }
    
    @objc func longPressed(_ timer: Timer) {
        _longPressed = true
    }
}

private extension CGPoint {
    func length(other point:CGPoint) -> CGFloat {
        return sqrt(pow(self.x-point.x, 2)+pow(self.y-point.y, 2))
    }
}
private extension Float {
    var cgfloat: CGFloat {
        return CGFloat(self)
    }
}
private extension Int {
    var cgfloat: CGFloat {
        return CGFloat(self)
    }
}

