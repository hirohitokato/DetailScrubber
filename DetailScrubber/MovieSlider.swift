//
//  MovieSlider.swift
//
//  Copyright (c) 2017 Hirohito Kato. MIT License.
//

import UIKit
import QuartzCore

@objc public protocol MovieSliderDelegate {
    /**
    Called whenever the slider's current stack changes.
    This is called when a stack mode is on. It's optinal method.

    - parameter slider: An object representing the movie slider notifying this information.
    - parameter index:  The stack index starts from 0(most left side)
    */
    func movieSlider(_ slider: MovieSlider, didChangeStackIndex index:Int)
}

extension MovieSliderDelegate {
    func movieSlider(_ slider: MovieSlider, didChangeStackIndex index:Int) {}
}

open class MovieSlider : DetailScrubber {
    private let kThumbImageSize : CGFloat = 20.0
    private let kThumbImageMargin : CGFloat = 10.0
    private let kThumbSize : CGFloat = 15.0
    private let kTrackHeight : CGFloat = 3.0
    private let kFrameGap: CGFloat = 2
    private var kFrameHeight: CGFloat {
        return minimumTrackImage(for: UIControl.State())!.size.height
    }

    public var stackMode: Bool = false {
        didSet {
            if stackMode != oldValue {
                showStacks(stackMode)
                _index = currentIndex
                if stackMode {
                    _value = value
                    setValue(0.5, animated: true)
                } else {
                    setValue(_value, animated: true)
                }
            }
        }
    }
    private var _stacks = [UIView]()
    private var _index: Int = 0
    private var _value: Float = 0.0

    public var numberOfStacks = 30 {
        didSet {
            guard stackMode == false else {
                print("Cannot change number of stacks during stack mode.")
                numberOfStacks = oldValue
                return
            }
        }
    }

    public weak var movieSliderDelegate: MovieSliderDelegate? = nil

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        _setupStacking()
        _setupAppearance()
        _value = value
    }
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        
        _setupStacking()
        _setupAppearance()
        _value = value
    }
    
}

private typealias MovieSlider_Appearance = MovieSlider
private extension MovieSlider_Appearance {
    func _setupAppearance() {
        tintColor = UIColor.white
        
        // thumb image
        setThumbImage(_imageForThumb(), for: UIControl.State())
        
        // track image
        let tracks = _imagesForTrack()
        setMinimumTrackImage(tracks.minImage, for: UIControl.State())
        setMaximumTrackImage(tracks.maxImage, for: UIControl.State())
    }
    
    func _imageForThumb() -> UIImage? {
        
        UIGraphicsBeginImageContextWithOptions(
            CGSize(width: kThumbImageSize,
                height: kThumbImageSize+kThumbImageMargin*3.0), false, 2.0)
        defer { UIGraphicsEndImageContext() }
        
        let ctx = UIGraphicsGetCurrentContext()
        ctx!.setFillColor(UIColor.white.cgColor)
        ctx!.setLineWidth(0.25)
        ctx!.addEllipse(in: CGRect(x: (kThumbImageSize-kThumbSize)/2.0,
                y: (kThumbImageSize+kThumbSize)/2.0,
                width: kThumbSize, height: kThumbSize))
        
        let shadowColor = UIColor.darkGray.cgColor
        let shadowOffset = CGSize(width: 0, height: 0.5)
        let shadowBlur : CGFloat = 1.0
        ctx!.setShadow(offset: shadowOffset, blur: shadowBlur, color: shadowColor);
        
        ctx!.drawPath(using: .fill)
        
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    func _imagesForTrack() -> (minImage: UIImage, maxImage: UIImage) {

        let minTrack: UIImage
        let maxTrack: UIImage

        // minimum track image
        do {
            UIGraphicsBeginImageContextWithOptions(
                CGSize(width: kTrackHeight, height: kTrackHeight), false, 2.0)
            defer { UIGraphicsEndImageContext() }

            let ctx = UIGraphicsGetCurrentContext()
            ctx!.setFillColor(UIColor.white.cgColor)
            ctx!.setLineWidth(0.25)
            ctx!.addArc(center: CGPoint(x:kTrackHeight/2, y:kTrackHeight/2), radius: kTrackHeight/2,
                        startAngle: _DEG2RAD(90), endAngle: _DEG2RAD(270), clockwise: false)
            ctx!.addLine(to: CGPoint(x: kTrackHeight, y: 0))
            ctx!.addLine(to: CGPoint(x: kTrackHeight, y: kTrackHeight))
            ctx!.addLine(to: CGPoint(x: kTrackHeight/2, y: kTrackHeight))
            ctx!.closePath()
            ctx!.drawPath(using: .fillStroke)

            let tmpImage = UIGraphicsGetImageFromCurrentImageContext()
            minTrack = tmpImage!.resizableImage(
                withCapInsets: UIEdgeInsets(top: 1, left: kTrackHeight/2, bottom: 1, right: 1),
                resizingMode: .tile)
        }
        
        // maximum track image
        do {
            UIGraphicsBeginImageContextWithOptions(
                CGSize(width: kTrackHeight, height: kTrackHeight), false, 2.0)
            defer { UIGraphicsEndImageContext() }

            let ctx = UIGraphicsGetCurrentContext()
            ctx!.setFillColor(UIColor.black.cgColor)
            ctx!.addArc(center: CGPoint(x:kTrackHeight/2, y:kTrackHeight/2), radius: kTrackHeight/2,
                        startAngle: _DEG2RAD(90), endAngle: _DEG2RAD(270), clockwise: true)
            ctx!.addLine(to: CGPoint(x: 0, y: 0))
            ctx!.addLine(to: CGPoint(x: 0, y: kTrackHeight))
            ctx!.addLine(to: CGPoint(x: kTrackHeight/2, y: kTrackHeight))
            ctx!.closePath()
            ctx!.drawPath(using: .fill)
            
            let tmpImage = UIGraphicsGetImageFromCurrentImageContext()
            maxTrack = tmpImage!.resizableImage(
                withCapInsets: UIEdgeInsets(top: 0, left: 0, bottom: 0, right: kTrackHeight/2),
                resizingMode: .tile)
        }
        
        return (minTrack, maxTrack)
    }
}

private typealias MovieSlider_UISliderMethods = MovieSlider
extension MovieSlider_UISliderMethods {
    open override func trackRect(forBounds bounds: CGRect) -> CGRect {
        var rect = CGRect.zero
        let dx : CGFloat = 2.0
        rect.origin.x = bounds.origin.x + dx
        rect.origin.y = bounds.origin.y + (bounds.size.height - kTrackHeight) / 2.0
        rect.size.width = bounds.size.width - (dx * 2.0)
        rect.size.height = kTrackHeight
        return rect
    }
    
    open override func thumbRect(forBounds bounds: CGRect, trackRect rect: CGRect, value: Float) -> CGRect {
        var thumbRect = super.thumbRect(forBounds: bounds, trackRect: rect, value: value)
        let thumbCenter = CGPoint(x: thumbRect.midX, y: thumbRect.midY)
        thumbRect.origin.x = thumbCenter.x - thumbRect.size.width/2;
        thumbRect.origin.y = thumbCenter.y - thumbRect.size.height/2;
        return thumbRect
    }
    
    open override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let view = super.hitTest(point, with: event)
        if view == self {
            // Only handle the point is on the thumb rect
            let trackRect = self.trackRect(forBounds: bounds)
            var thumbRect = self.thumbRect(forBounds: bounds, trackRect:trackRect, value:value)
            
            // The area of handle point is greater than the size of thumb
            thumbRect.origin.x -= thumbRect.size.width
            thumbRect.size.width += 2 * thumbRect.size.width
            if !thumbRect.contains(point) {
                return nil
            }
        }
        return view
    }
}

// MARK: - Long Press Event
private typealias MovieSlider_StackingMode = MovieSlider
extension MovieSlider_StackingMode {
    fileprivate func _setupStacking() {
    }

    fileprivate func showStacks(_ isOn: Bool) {
        if !isOn {
            _stacks.forEach{ $0.removeFromSuperview() }
            _stacks.removeAll()
            UIView.animate(withDuration: 0.15, animations: {
                self.subviews[0].alpha = 1.0
                self.subviews[1].alpha = 1.0
            }) 
            return
        }

        (0..<numberOfStacks).forEach { _ in
            let v = UIView(frame: CGRect.zero)
            v.backgroundColor = UIColor.black
            v.layer.borderWidth = 0.5
            v.layer.borderColor = UIColor.darkGray.cgColor
            _stacks.append(v)
        }

        let thumbImage = self.thumbImage(for: UIControl.State())
        let minTrackIndex = subviews.index { v -> Bool in
            if let imageView = v as? UIImageView {
                return imageView.image == thumbImage
            } else {
                return false
            }
        }

        let trackRect = self.trackRect(forBounds: bounds)
        let thumbRect = self.thumbRect(forBounds: bounds, trackRect:trackRect, value:value)

        var x: CGFloat = thumbRect.midX
        let y: CGFloat = (frame.height-kFrameHeight)/2
        let width: CGFloat = (frame.width - kFrameGap*(CGFloat(numberOfStacks-1))) / CGFloat(numberOfStacks)
        let height: CGFloat = kFrameHeight

        _stacks.forEach{
            insertSubview($0, at: minTrackIndex!)
            $0.frame = CGRect(x: x, y: y, width: width, height: height)
        }

        x = 0.0
        UIView.animate(withDuration: 0.2, animations: {
            self.subviews[0].alpha = 0.0
            self.subviews[1].alpha = 0.0
            self._stacks.forEach {
                $0.frame = CGRect(x: x, y: y, width: width, height: height)
                x += width + self.kFrameGap
            }
        }) 
        updateStack()
    }

    open var currentIndex: Int {
        let valueRange = maximumValue - minimumValue
        let range = Int(((value - minimumValue)/valueRange) * Float(numberOfStacks))
        let currentIndex = min(range, numberOfStacks-1)
        return currentIndex
    }

    fileprivate func updateStack() {
        if stackMode {
            for v in _stacks {
                v.backgroundColor = UIColor.black
            }
            _stacks[currentIndex].backgroundColor = UIColor.white
        }
    }

    open override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let beginTracking = super.beginTracking(touch, with: event)

        notifyIndexIfNeeded()
        updateStack()
        return beginTracking
    }

    open override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let continueTracking = super.continueTracking(touch, with: event)

        notifyIndexIfNeeded()
        updateStack()
        return continueTracking
    }

    open override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        super.endTracking(touch, with: event)

        notifyIndexIfNeeded()
        updateStack()
    }

    open override func sendActions(for controlEvents: UIControl.Event) {
        if !stackMode {
            super.sendActions(for: controlEvents)
        }
    }

    fileprivate func notifyIndexIfNeeded() {
        if stackMode && _index != currentIndex {
            _index = currentIndex
            movieSliderDelegate?.movieSlider(self, didChangeStackIndex: currentIndex)
        }
    }
}

private func _DEG2RAD(_ deg: CGFloat) -> CGFloat {
    return deg * CGFloat.pi / 180.0
}
