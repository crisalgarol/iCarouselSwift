//
//  iCarouselView.swift
//
//  Ported to Swift by Cristian Olmedo, 2025
//  Original Objective-C version by Nick Lockwood (© 2011 Charcoal Design)
//
//  This software is provided 'as-is', without any express or implied warranty.
//  In no event will the authors be held liable for any damages arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it freely,
//  subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented;
//     you must not claim that you wrote the original software.
//     If you use this software in a product, an acknowledgment in the product documentation
//     would be appreciated but is not required.
//
//  2. Altered source versions must be plainly marked as such,
//     and must not be misrepresented as being the original software.
//
//  3. This notice may not be removed or altered from any source distribution.
//

import UIKit
import ObjectiveC.runtime

public protocol iCarouselCore {
    func scrollByOffset(offset: CGFloat, duration: TimeInterval)
    func scrollToOffset(offset: CGFloat, duration: TimeInterval)
    func scrollByNumberOfItems(itemCount: Int, duration: TimeInterval)
    func scrollToItem(index: Int, animated: Bool)
    
    func itemView(index: Int) -> UIView
    func indexOfItemView(view: UIView) -> Int?
    func offsetForItem(index: Int) -> CGFloat
    func itemView(at point: CGPoint) -> UIView?
    
    func removeItem(index: Int, animated: Bool)
    func insertItem(index: Int, animated: Bool)
    func reloadItem(index: Int, animated: Bool)
    
    func reloadData()
}

open class iCarouselView: UIView {
    
    var type: iCarouselType = .linear {
        didSet {
            layoutItemViews()
        }
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    init(dataSource: iCarouselDataSource, type: iCarouselType) {
        self.dataSource = dataSource
        self.type = type
        super.init(frame: .zero)
        self.translatesAutoresizingMaskIntoConstraints = false
        setUp()
    }
    
    var dataSource: iCarouselDataSource {
        didSet {
            // TODO: Avoid using reload data
            reloadData()
        }
    }

    weak var delegate: iCarouselDelegate? {
        didSet {
            setNeedsLayout()
        }
    }
    
    var maxVisibleItems: Int {
        #if os(iOS)
        return 30
        #else
        return 50
        #endif
    }
    
    let minToggleDurationDefault: CGFloat = 0.2
    let maxToggleDurationDefault: CGFloat = 0.4
    let scrollDurationDefault: CGFloat = 0.4
    let insertDurationDefault: CGFloat = 0.4
    let decelerateThresholdDefault: CGFloat = 0.1
    let scrollSpeedThresholdDefault: CGFloat = 2.0
    let scrollDistanceThresholdDefault: CGFloat = 0.1
    let decelerationMultiplierDefault: CGFloat = 30.0
    let floatErrorMarginDefault: CGFloat = 0.000001
    
    // CGFloats
    var perspective: CGFloat = .zero {
        didSet {
            transformItemViews()
        }
    }
    var decelerationRate: CGFloat = 0
    
    var decelerationDistance: CGFloat {
        let acceleration = -startVelocity * decelerationMultiplierDefault * (1.0 - decelerationRate)
        return -pow(startVelocity, 2.0) / (2.0 * acceleration)
    }

    var shouldDecelerate: Bool {
        return abs(startVelocity) > scrollSpeedThresholdDefault &&
               abs(decelerationDistance) > decelerateThresholdDefault
    }

    var shouldScroll: Bool {
        return abs(startVelocity) > scrollSpeedThresholdDefault &&
               abs(scrollOffset - CGFloat(currentItemIndex())) > scrollDistanceThresholdDefault
    }

    var scrollSpeed: CGFloat = 0
    var bounceDistance: CGFloat = 0
    
    var isScrollEnabled = false
    var isPagingEnabled = false
    
    var isVertical: Bool = false {
        didSet {
            layoutItemViews()
        }
    }
    
    // TODO: ReadOnly, Getter
    var isWrapEnabled = false
    
    var bounces = false
    var scrollOffset: CGFloat = .zero {
        willSet {
            isScrolling = false
            isDecelerating = false
            startOffset = newValue
            endOffset = newValue
        }
        
        didSet {
            // TO IMPROVE: Check new tolerance performance
            if abs(oldValue - scrollOffset) > 0.0 {
                depthSortViews()
                didScroll()
            }
        }
    }
    
    // TODO: ReadOnly
    var offsetMultiplier: CGFloat = CGFloat()
    
    var contentOffset: CGSize = .zero {
        didSet {
            if oldValue != contentOffset {
                layoutItemViews()
            }
        }
    }

    var viewPointOffset: CGSize = .zero {
        didSet {
            if oldValue != viewPointOffset {
                transformItemViews()
            }
        }
    }
    
    // TODO: ReadOnly
    var numberOfItems = 0
    var numberOfPlaceholders = 0

    var currentItemView: UIView {
        itemView(index: currentItemIndex())
    }
    
    // TODO: ReadOnly
    // TO IMPROVE: Evaluate replacing with a Sorted Set
    var indexesForVisibleItems: [Int] {
        itemViews.keys.sorted(by: <)
    }

    var numberOfVisibleItems = 0

    // TODO: ReadOnly
    var visibleItemViews: [UIView] {
        let sortedViews = itemViews.sorted { firstElement, secondElement in
            firstElement.key < secondElement.key
        }
        return sortedViews.map { (key, value) in
            return value
        }
    }

    // TODO: ReadOnly
    var itemWidth: CGFloat = 0
    // TODO: Read only, pero no deberia ser optional
    var contentView = UIView()
    // TODO: ReadOnly
    var toggle: CGFloat = 0
    
    var autoscroll: CGFloat = .zero {
        didSet {
            if autoscroll != .zero {
                startAnimation()
            }
        }
    }

    var stopAtItemBoundary = false
    var scrollToItemBoundary = false
    var ignorePerpendicularSwipes = false
    var centerItemWhenSelected = false
    
    // TODO: ReadOnly, Getter
    var isDragging = false
    
    // MARK: Implementations of .m file
    var itemViews: [Int: UIView] = [:]
    var itemViewPool: Set<UIView> = []
    var placeholderViewPool: Set<UIView> = []
    
    var previousScrollOffset: CGFloat = 0
    var previousItemIndex: Int = 0
    
    var numberOfPlaceholdersToShow: Int = 0
    
    var startOffset: CGFloat = 0
    var endOffset: CGFloat = 0
    
    var scrollDuration: TimeInterval = 0
    
    var isScrolling: Bool = false
    
    var startTime: TimeInterval = 0
    var lastTime: TimeInterval = 0
    var startVelocity: CGFloat = 0
    
    var timer: Timer?
    
    var isDecelerating: Bool = false
    var previousTranslation: CGFloat = 0
    
    var didDrag: Bool = false
    
    var toggleTime: TimeInterval = 0
    
    //MARK: VIEW QUEING
    
    func queueItemView(view: UIView) {
        itemViewPool.insert(view)
    }
    
    func queuePlaceholderView(view: UIView) {
        placeholderViewPool.insert(view)
    }
    
    var dequeueItemView: UIView {
        if let view = itemViewPool.first {
            itemViewPool.remove(view)
            return view
        }
        // TO IMPROVE, might be good to return nil
        return UIView()
    }
    
    var dequeuePlaceholderView: UIView {
        if let view = placeholderViewPool.first {
            placeholderViewPool.remove(view)
            return view
        }

        // TO IMPROVE, might be good to return nil
        return UIView()
    }
    
    deinit {
        stopAnimation()
    }
    
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        contentView.frame = self.bounds
        layoutItemViews()
    }
    
    func compareViewDepth(viewOne: UIView, viewTwo: UIView, in carousel: iCarouselView) -> ComparisonResult {
        guard let tOne = viewOne.superview?.layer.transform,
              let tTwo = viewTwo.superview?.layer.transform else {
            // Si alguna no tiene superview, considera que no puede compararse bien
            return .orderedSame
        }

        let zOne = tOne.m13 + tOne.m23 + tOne.m33 + tOne.m43
        let zTwo = tTwo.m13 + tTwo.m23 + tTwo.m33 + tTwo.m43
        var difference = zOne - zTwo

        if difference == 0.0 {
            guard let currentTransform = carousel.currentItemView.superview?.layer.transform else {
                return .orderedSame
            }
            
            if carousel.isVertical {
                let yOne = tOne.m12 + tOne.m22 + tOne.m32 + tOne.m42
                let yTwo = tTwo.m12 + tTwo.m22 + tTwo.m32 + tTwo.m42
                let yThree = currentTransform.m12 + currentTransform.m22 + currentTransform.m32 + currentTransform.m42
                difference = abs(yTwo - yThree) - abs(yOne - yThree)
            } else {
                let xOne = tOne.m11 + tOne.m21 + tOne.m31 + tOne.m41
                let xTwo = tTwo.m11 + tTwo.m21 + tTwo.m31 + tTwo.m41
                let xThree = currentTransform.m11 + currentTransform.m21 + currentTransform.m31 + currentTransform.m41
                difference = abs(xTwo - xThree) - abs(xOne - xThree)
            }
        }

        return (difference < 0.0) ? .orderedAscending : .orderedDescending
    }
    
    func layoutItemViews() {
        // Update Wrap
        switch type {
        case .rotary, .invertedRotary, .cylinder, .invertedCylinder, .wheel, .invertedWheel:
            isWrapEnabled = true
        case .coverFlow, .coverFlowTwo, .timeMachine, .invertedTimeMachine, .linear, .custom:
            isWrapEnabled = false
        }
        
        isWrapEnabled = valueForOption(option: .wrap, defaultValue: CGFloat(isWrapEnabled.hashValue)) != .zero
        
        // No placeholder on wrapped carousels
        numberOfPlaceholdersToShow = isWrapEnabled ? .zero : numberOfPlaceholders
        
        // Set item width
         updateItemWidth()
        
        // Update number of visible items
        updateNumberOfVisibleItems()
        
        // Prevent false index changed event
        previousScrollOffset = scrollOffset
        
        // Update Offset multiplier
        
        let baseMultiplier: CGFloat = (type == .coverFlow || type == .coverFlowTwo) ? 2.0 : 1.0
        offsetMultiplier = valueForOption(option: .offsetMultiplier, defaultValue: baseMultiplier)
        
        // Align
        if !isScrolling && !isDecelerating && autoscroll == .zero {
            if scrollToItemBoundary && currentItemIndex() != -1 {
                scrollToItem(index: currentItemIndex(), animated: true)
            } else {
                scrollOffset = clampedOffset(offset: scrollOffset)
            }
        }
    
        // Update Views
        didScroll()
    }
    
    // MARK: SCROLLING
    func clampedIndex(index: Int) -> Int {
        
        if numberOfItems == 0 {
            return -1
        }
        else if isWrapEnabled {
            return index - Int((CGFloat(index) / CGFloat(numberOfItems)).rounded(.down)) * numberOfItems
        } else {
            return min( max(.zero, index), max(.zero, numberOfItems - 1) )
        }
    }
    
    func clampedOffset(offset: CGFloat) -> CGFloat {
        if numberOfItems == .zero {
            return -1.0
        }
        else if isWrapEnabled {
            return offset - floor(offset / CGFloat(numberOfItems)) * CGFloat(numberOfItems)
        }
        
        return min( max(0.0, offset), max(0.0, CGFloat(numberOfItems) - 1.0) )
    }
    
    func currentItemIndex() -> Int {
        return clampedIndex(index: Int(scrollOffset.rounded()))
    }
    
    func minScrollDistance(from fromIndex: Int, to toIndex: Int) -> Int {
        let directDistance = toIndex - fromIndex
        
        if isWrapEnabled {
            
            var wrappedDistance = min(toIndex, fromIndex) + numberOfItems - max(toIndex, fromIndex)
            
            if fromIndex < toIndex {
               wrappedDistance *= -1
            }
            
            return (abs(directDistance) <= abs(wrappedDistance)) ? directDistance : wrappedDistance
        }
        
        return directDistance
    }
    
    func minSrollDistanceFromOffset(from fromOffset: CGFloat, to toOffset: CGFloat) -> CGFloat {
        let directDistance = toOffset - fromOffset
        
        if isWrapEnabled {
            var wrappedDistance: CGFloat = min(toOffset, fromOffset) + CGFloat(numberOfItems) - max(toOffset, fromOffset)
            
            if fromOffset < toOffset {
                wrappedDistance *= -1
            }
            
            return ( abs(directDistance) <= abs(wrappedDistance) ) ? directDistance : wrappedDistance
        }
        
        return directDistance
    }
    
    public func scrollByOffset(offset: CGFloat, duration: TimeInterval) {
        guard duration > .zero else {
            scrollOffset += offset
            return
        }
        
        isDecelerating = false
        isScrolling = true
        startTime = CACurrentMediaTime()
        scrollDuration = duration
        endOffset = startOffset + offset
        
        if isWrapEnabled {
            endOffset = clampedOffset(offset: endOffset)
        }
        
        delegate?.willBeginScrollingAnimation(carousel: self)
        startAnimation()
    }

    public func scrollToOffset(offset: CGFloat, duration: TimeInterval) {
        scrollByOffset(offset: minSrollDistanceFromOffset(from: scrollOffset, to: offset),
                       duration: duration)
    }
    
    public func scrollByNumberOfItems(itemCount: Int, duration: TimeInterval) {
        guard duration > .zero else {
            scrollOffset = CGFloat(clampedIndex(index: previousItemIndex + itemCount))
            return
        }
        
        var offset = CGFloat()
        
        if itemCount > .zero {
            offset = floor(scrollOffset) + CGFloat(itemCount) - scrollOffset
        } else if itemCount < .zero {
            offset = ceil(scrollOffset) + CGFloat(itemCount)  - scrollOffset
        } else {
            offset = round(scrollOffset) - scrollOffset
        }
        
        scrollByOffset(offset: offset, duration: duration)
    }
    
    func scrollToItem(index: Int, duration: TimeInterval) {
        scrollToOffset(offset: CGFloat(index), duration: duration)
    }
    
    public func scrollToItem(index: Int, animated: Bool) {
        scrollToItem(index: index, duration: animated ? scrollDuration : .zero)
    }
    
    func circularCarouselItemCount() -> Int {
        var count = 0
        
        switch type {
        case .coverFlow, .coverFlowTwo, .timeMachine, .invertedTimeMachine, .linear, .custom:
            return numberOfItems + numberOfPlaceholdersToShow
        case .rotary, .invertedRotary, .cylinder, .invertedCylinder, .wheel, .invertedWheel:
            // Slightly arbitrary number, chosen for aesthetic reasons
            let spacing = valueForOption(option: .optionSpacing,
                                         defaultValue: 1.0)
            let width = isVertical ? bounds.size.height : bounds.size.width
            count = min(maxVisibleItems,
                        Int(max(12.0, ceil(width / (spacing * itemWidth)) * .pi)))
            count = min(Int(CGFloat(numberOfItems + numberOfPlaceholdersToShow)), count)
        }
        
        return Int(valueForOption(option: .optionCount,
                                  defaultValue: CGFloat(count)))
    }
}

extension iCarouselView {
    func setUp() {
        decelerationRate = 0.95
        isScrollEnabled = true
        bounces = true
        offsetMultiplier = 1.0
        perspective = -1.0 / 500.0
        contentOffset = .zero
        viewPointOffset = .zero
        scrollSpeed = 1.0
        bounceDistance = 1.0
        stopAtItemBoundary = true
        scrollToItemBoundary = true
        ignorePerpendicularSwipes = true
        centerItemWhenSelected = true
        
        contentView = UIView(frame: self.bounds)
        
        #if os(iOS)
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Add Pan Gesture Recogniser
        let panGesture = UIPanGestureRecognizer(target: self,
                                                action: #selector(didPan(_:)))
        panGesture.delegate = self
        contentView.addGestureRecognizer(panGesture)
        
        // Add tap Gesture Recogniser
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTap))
        tapGesture.delegate = self
        contentView.addGestureRecognizer(tapGesture)
        
        // Set up accessibility
        accessibilityTraits = .allowsDirectInteraction
        isAccessibilityElement = true
        
        #elseif os(macOS)
        // TODO: Checar la interoperabilidad
        // contentView.wantsLayer = true
        #endif
        
        addSubview(contentView)
        
        reloadData()
    }
    
    func pushAnimationState(enabled: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(!enabled)
    }
    
    func popAnimationState() {
        CATransaction.commit()
    }
    
    func depthSortViews() {
        #if os(macOS)
        return
        #endif
        
        let currentViews = itemViews.values.sorted { viewOne, viewTwo in
            compareViewDepth(viewOne: viewOne, viewTwo: viewTwo, in: self) == .orderedAscending
        }
        
        for currentView in currentViews {
            if let superview = currentView.superview {
                contentView.bringSubviewToFront(superview)
            }
        }
    }
        
    func setCurrentItem(index: Int) {
        scrollOffset = CGFloat(index)
    }
    
    func transformItemViews() {
        for number in itemViews.keys {
            if let viewToTransform = itemViews[number] {
                transformForItem(view: viewToTransform, index: number)
            }
        }
    }
    
    func updateItemWidth() {
        if let delegateWidth = delegate?.carouselItemWidth(carousel: self), delegateWidth != 0 {
            itemWidth = delegateWidth
        }
        
        if itemViews.isEmpty {
            if numberOfItems > 0 {
                loadView(at: .zero)
            } else if numberOfPlaceholders > 0 {
                loadView(at: -1)
            }
        }
    }
    
    func updateNumberOfVisibleItems() {
        switch type {
        case .linear:
            let spacing = valueForOption(option: .optionSpacing, defaultValue: 1.0)
            let width = isVertical ? self.bounds.size.height : self.bounds.size.width
            let itemWidth = itemWidth * spacing
            
            numberOfVisibleItems = Int(ceil(width / itemWidth) + 2.0)
        
        case .coverFlow, .coverFlowTwo:
            let spacing = valueForOption(option: .optionSpacing, defaultValue: 0.25)
            let width = isVertical ? self.bounds.size.height : self.bounds.size.width
            let itemWidth = itemWidth * spacing
            numberOfVisibleItems = Int(ceil(width / itemWidth) + 2.0)
            
        case .rotary, .cylinder:
             numberOfVisibleItems = circularCarouselItemCount()
        
        case .invertedRotary, .invertedCylinder:
            numberOfVisibleItems = Int(ceil(Double(circularCarouselItemCount()) / 2.0))
        
        case .wheel, .invertedWheel:
            let count = circularCarouselItemCount()
            let spacing = valueForOption(option: .optionSpacing, defaultValue: 1.0)
            let arc = valueForOption(option: .optionARC, defaultValue: .pi * 2.0)
            let radius = valueForOption(option: .optionRadius,
                                        defaultValue: itemWidth * spacing * CGFloat(count) / arc)
            
            if radius - itemWidth / 2.0 < min(bounds.size.width, bounds.size.height) / 2.0 {
                numberOfVisibleItems = count
            } else {
                numberOfVisibleItems = Int(ceil(Double(count) / 2.0)) + 1
            }
            
        case .timeMachine, .invertedTimeMachine, .custom:
            //slightly arbitrary number, chosen for performance reasons
            numberOfVisibleItems = maxVisibleItems
        }
        
        numberOfVisibleItems = min(maxVisibleItems, numberOfVisibleItems)
        numberOfVisibleItems = Int(valueForOption(option: .visibleItems, defaultValue: CGFloat(numberOfVisibleItems)))
        numberOfVisibleItems = max(.zero, min(numberOfVisibleItems, numberOfItems + numberOfPlaceholdersToShow))
    }
    
    func transformForItem(view: UIView, index: Int) {
        // Calcute Offset
        let currentOffset = offsetForItem(index: index)
        
        // Update Alpha
        view.superview?.layer.opacity = alphaForItem(offset: currentOffset)
        
        #if os(iOS)
        
        // Center View
        view.superview?.center = CGPointMake(bounds.size.width / 2.0 + contentOffset.width,
                                             bounds.size.height / 2.0 + contentOffset.height)
        
        // Enable disable interaction
        view.superview?.isUserInteractionEnabled = !centerItemWhenSelected || index == currentItemIndex()
        
        // Account for retina
        view.superview?.layer.rasterizationScale = UIScreen.main.scale
        view.layoutIfNeeded()
        
        #else
        
        //TO CHECK: Mac OS Implementation not compatible lines 837 - 843
        #endif
        
        // Special Case Logic for Type CoverFlow 2
        let clampedOffset = max(-1.0, min(1.0, currentOffset))
        
        if isDecelerating
            || (isScrolling && !isDragging && !didDrag)
            || (autoscroll != .zero && !isDragging)
            || (!isWrapEnabled &&
                (scrollOffset < .zero || scrollOffset >= CGFloat(numberOfItems - 1) )) {
            
            if currentOffset > .zero {
                toggle = (currentOffset <= 0.5) ? -clampedOffset : (1.0 - clampedOffset)
            } else {
                toggle = (currentOffset > -0.5) ? -clampedOffset : (-1.0 - clampedOffset)
            }
        }
        
        // Calculate Transform
        let transform: CATransform3D = transformForItemView(offset: currentOffset)
        
        // Transform View
        view.superview?.layer.transform = transform
        
        // Backface Culling
        var showBackfaces = view.layer.isDoubleSided
        
        if showBackfaces {
            switch type {
            case .invertedCylinder:
                showBackfaces = false
            default:
                showBackfaces = true
            }
        }
        
        showBackfaces = valueForOption(option: .showBackFaces,
                                       defaultValue: showBackfaces ? 1 : 0) != 0.0
        
        //we can't just set the layer.doubleSided property because it doesn't block interaction
        //instead we'll calculate if the view is front-facing based on the transform
        let backfaceVisible = ( (showBackfaces ? 1 : .zero) != .zero) ? true : (transform.m33 > .zero)
        view.superview?.isHidden = !backfaceVisible
    }
    
    func transformForItemView(offset: CGFloat) -> CATransform3D {
        // Set up base transform
        var transform = CATransform3DIdentity
        transform.m34 = perspective
        transform = CATransform3DTranslate(transform,
                                           -viewPointOffset.width,
                                           -viewPointOffset.height,
                                           .zero)
        
        // Perform Transform
        
        guard let delegate else {
            return CATransform3D()
        }
        
        switch type {
        case .custom:
            return delegate.carousel(itemTransformOffset: offset,
                                      baseTransform: transform)
            
        case .linear:
            let spacing: CGFloat = valueForOption(option: .optionSpacing,
                                                  defaultValue: 1.0)
            
            if isVertical {
                return CATransform3DTranslate(transform,
                                              .zero,
                                              offset * itemWidth * spacing,
                                              .zero)
            } else {
                return CATransform3DTranslate(transform,
                                              offset * itemWidth * spacing,
                                              .zero,
                                              .zero)
            }
            
        case .rotary, .invertedRotary:
            let count = circularCarouselItemCount()
            let spacing: CGFloat = valueForOption(option: .optionSpacing,
                                         defaultValue: 1.0)
            let arc = valueForOption(option: .optionARC,
                                     defaultValue: .pi * 2.0)
            
            let halfSpacing = itemWidth * spacing / 2.0
            let denominator = tan(arc / 2.0 / CGFloat(count))
            let secondTerm = halfSpacing / denominator
            let defaultRadius: CGFloat = max(halfSpacing, secondTerm)

            var radius = valueForOption(option: .optionRadius,
                                        defaultValue: defaultRadius)
            var angle = valueForOption(option: .optionAngle,
                                       defaultValue: offset / CGFloat(count) * arc)
            
            if type == .invertedRotary {
                radius *= -1
                angle *= -1
            }
            
            if isVertical {
                return CATransform3DTranslate(transform,
                                              .zero,
                                              radius * sin(angle),
                                              radius * cos(angle) - radius)
            } else {
                return CATransform3DTranslate(transform,
                                              radius * sin(angle),
                                              .zero,
                                              radius * cos(angle) - radius)
            }
            
        case .cylinder, .invertedCylinder:
            let count = circularCarouselItemCount()
            let spacing = valueForOption(option: .optionSpacing, defaultValue: 1.0)
            let arc = valueForOption(option: .optionARC, defaultValue: .pi * 2.0)
            
            let defaultRadius = max(1/100,itemWidth * spacing / 2.0 / tan(arc / 2.0 / CGFloat(count)))
            var radius = valueForOption(option: .optionRadius, defaultValue: defaultRadius)
            var angle = valueForOption(option: .optionAngle, defaultValue: offset / CGFloat(count) * arc)
            
            if type == .invertedCylinder {
                radius *= -1
                angle *= -1
            }
            
            // TO IMPROVE: Transform declared twice, avoid this
            if isVertical {
                transform = CATransform3DTranslate(transform, .zero, .zero, -radius)
                transform = CATransform3DRotate(transform, angle, -1.0, .zero, .zero)
                return CATransform3DTranslate(transform, .zero, .zero, radius + 1/100)
            } else {
                transform = CATransform3DTranslate(transform, .zero, .zero, -radius)
                transform = CATransform3DRotate(transform, angle, .zero, 1.0, .zero)
                return CATransform3DTranslate(transform, .zero, .zero, radius + 0.01)
            }
            
        case .wheel, .invertedWheel:
            let count = circularCarouselItemCount()
            let spacing = valueForOption(option: .optionSpacing, defaultValue: 1.0)
            let arc = valueForOption(option: .optionARC, defaultValue: .pi * 2.0)
            var radius = valueForOption(option: .optionRadius, defaultValue: itemWidth * spacing * CGFloat(count) / arc)
            var angle = valueForOption(option: .optionAngle, defaultValue: arc / CGFloat(count))
            
            if type == .invertedWheel {
                radius *= -1
                angle *= -1
            }
            
            if isVertical {
                transform = CATransform3DTranslate(transform, -radius, .zero, .zero)
                transform = CATransform3DRotate(transform, angle * offset, .zero, .zero, 1.0)
                return CATransform3DTranslate(transform, radius, .zero, offset * 0.01)
            } else {
                transform = CATransform3DTranslate(transform, .zero, radius, .zero)
                transform = CATransform3DRotate(transform, angle * offset, .zero, .zero, 1.0)
                return CATransform3DTranslate(transform, .zero, -radius, offset * 0.01)
            }
        
        case .coverFlow, .coverFlowTwo:
            let halfStep = 0.5
    
            let tilt = valueForOption(option: .optionTilt, defaultValue: 0.9)
            let spacing = valueForOption(option: .optionSpacing, defaultValue: 0.25)
            var clampedOffset = max(-1.0, min(1.0, offset))
            
            if type == .coverFlowTwo {
                if toggle > 0.5 {
                    if offset <= -halfStep {
                        clampedOffset = -1.0
                    } else if offset <= halfStep {
                        clampedOffset = -toggle
                    } else if offset <= 1.5 {
                        clampedOffset = 1.0 - toggle
                    }
                } else {
                    if offset > halfStep {
                        clampedOffset = 1.0
                    } else if offset > -halfStep {
                        clampedOffset = -toggle
                    } else if offset > -1.5 {
                        clampedOffset = -1.0 - toggle
                    }
                }
            }

            let x = ( clampedOffset * halfStep * tilt + offset * spacing ) * itemWidth
            let z = abs(clampedOffset) * -itemWidth * halfStep
            let tiltAngle = -clampedOffset * (.pi / 2.0) * tilt
            
            if isVertical {
                transform = CATransform3DTranslate(transform, .zero, x, z)
                return CATransform3DRotate(transform, tiltAngle, -1.0, .zero, .zero)
            } else {
                transform = CATransform3DTranslate(transform, x, .zero, z)
                return CATransform3DRotate(transform, tiltAngle, .zero, 1.0, .zero)
            }
            
        case .timeMachine, .invertedTimeMachine:
            var tilt = valueForOption(option: .optionTilt, defaultValue: 0.3)
            let spacing = valueForOption(option: .optionSpacing, defaultValue: 1.0)
            var timeMachineOffset = offset
            
            if type == .invertedTimeMachine {
                tilt *= -1
                timeMachineOffset *= -1
            }
            
            if isVertical {
                #if os(macOS)
                tilt *= -1
                timeMachineOffset *= -1
                #endif
                return CATransform3DTranslate(transform,
                                              .zero,
                                              timeMachineOffset * itemWidth * tilt,
                                              timeMachineOffset * itemWidth * spacing)
            }
            
            return CATransform3DTranslate(transform,
                                          timeMachineOffset * itemWidth * tilt,
                                          .zero,
                                          timeMachineOffset * itemWidth * spacing)
        }
    }
    
    func adaptiveDefault(for option: iCarouselOption) -> CGFloat {
        switch option {
        case .optionSpacing:
            return bounds.width > 600 ? 1.2 : 1.0
        case .optionTilt:
            return bounds.width > 600 ? 1.1 : 0.9
        case .optionARC:
            return bounds.width > 600 ? 0.6 : 0.5
        default:
            return 0
        }
    }
    
    func alphaForItem(offset: CGFloat) -> Float {
        
        var fadeMin = CGFloat(integerLiteral: .min)
        var fadeMax = CGFloat(integerLiteral: .max)
        var fadeRange: CGFloat = 1
        var fadeMinAlpha: CGFloat = .zero
        
        switch type {
        case .timeMachine:
            fadeMax = .zero
        case .invertedTimeMachine:
            fadeMin = .zero
        default:
            break
        }
        
        // TODO IMPROVE: Value For Option returns the same value
        fadeMin = valueForOption(option: .optionFadeMin, defaultValue: fadeMin)
        fadeMax = valueForOption(option: .optionFadeMax, defaultValue: fadeMax)
        fadeRange = valueForOption(option: .optionFadeRange, defaultValue: fadeRange)
        fadeMinAlpha = valueForOption(option: .optionFadeMinAlpha, defaultValue: fadeMinAlpha)
        
        #if os(macOS)
        if isVertical {
            offset *= -1
        }
        #endif
        
        var factor: CGFloat = .zero
        
        if offset > fadeMax {
            factor = offset - fadeMax
        } else if offset < fadeMin {
            factor = fadeMin - offset
        }
        
        return Float(1 - min(factor, fadeRange) / fadeRange * (1.0 - fadeMinAlpha))
    }
    
    func valueForOption(option: iCarouselOption, defaultValue: CGFloat) -> CGFloat {
        return delegate?.carousel(carousel: self,
                                  valueForOption: option,
                                  withDefault: defaultValue) ?? .zero
    }
}

// MARK: Carousel Function Core
extension iCarouselView: iCarouselCore {
    
    public func itemView(index: Int) -> UIView {
        return itemViews[index] ?? UIView()
    }
    
    public func indexOfItemView(view: UIView) -> Int? {
        return itemViews.first(where: { $0.value === view })?.key
    }
    
    public func loadView(at index: Int) -> UIView {
        return loadView(at: index, containerView: nil)
    }
    
    public func loadView(at index: Int, containerView: UIView?) -> UIView {
        pushAnimationState(enabled: false)
        
        var view = UIView()
        
        if index < .zero {
            let placeholderIndex = Int(ceil(Double(numberOfPlaceholdersToShow) / 2.0)) + index
            view = dataSource.carousel(self,
                                       placeholderViewAt: placeholderIndex,
                                       reusing: dequeuePlaceholderView)
        } else if index >= numberOfItems {
            let placeholderIndex = numberOfPlaceholdersToShow / 2 + index - numberOfItems
            view = dataSource.carousel(self,
                                       placeholderViewAt: placeholderIndex,
                                       reusing: dequeuePlaceholderView)
        } else {
            view = dataSource.carousel(carousel: self,
                                       viewForItemAt: index,
                                       reusingView: dequeueItemView)
        }
        
        itemViews[index] = view
        
        if let containerView {
            // Get Old Item View
            if let oldItemView = containerView.subviews.last {
                if index < 0 || index >= numberOfItems {
                    queuePlaceholderView(view: oldItemView)
                } else {
                    queueItemView(view: oldItemView)
                }
            }
            
            // Set Container Frame
            var frame = containerView.bounds
            
            if isVertical {
                frame.size.width = view.frame.width
                frame.size.height = min(itemWidth, view.frame.size.height)
            } else {
                frame.size.width = min(itemWidth, view.frame.size.width)
                frame.size.height = view.frame.size.height
            }
            
            containerView.bounds = frame
            
            // Set View Frame
            frame = view.frame
            frame.origin.x = (containerView.bounds.size.width - frame.size.width) / 2.0
            frame.origin.y = (containerView.bounds.size.height - frame.size.height) / 2.0
            view.frame = frame
            
            // Switch views
            containerView.subviews.last?.removeFromSuperview()
            containerView.addSubview(view)
            
        } else {
            contentView.addSubview(containView(view))
        }
        
        view.superview?.layer.opacity = .zero
        transformForItem(view: view, index: index)
        popAnimationState()
        
        return view
    }
    
    func loadUnloadViews() {
        // Set item width
        updateItemWidth()
        
        // Update number of visible items
        updateNumberOfVisibleItems()
        
        // Calculate visible view indices
        var visibleIndices = Set<Int>()
        let minValue = -Int(ceil(Double(numberOfPlaceholdersToShow) / 2.0))
        let maxValue = numberOfItems - 1 + numberOfPlaceholdersToShow / 2
        var offset = currentItemIndex() - numberOfVisibleItems / 2
        
        if isWrapEnabled {
            offset = max(minValue, min(maxValue - numberOfVisibleItems + 1, offset))
        }
        
        for number in 0..<numberOfVisibleItems {
            var index = number + offset
            
            if isWrapEnabled {
                index = clampedIndex(index: index)
            }
            
            let alpha = alphaForItem(offset: offsetForItem(index: index))
            
            // Load only views with alpha > 0
            if alpha > .zero {
                visibleIndices.insert(index)
            }
            
            // Remove OffScreen views
            for number in Array(itemViews.keys) {
                if !visibleIndices.contains(number) {
                    if let view = itemViews[number] {
                        if number < 0 || number >= numberOfItems {
                            queuePlaceholderView(view: view)
                        } else {
                            queueItemView(view: view)
                        }
                        view.superview?.removeFromSuperview()
                        itemViews.removeValue(forKey: number)
                    }
                }
            }
            
            // Add On Screen Views
            for number in visibleIndices {
                if itemViews[number] == nil {
                    loadView(at: number)
                }
            }
        }
    }
    
    public func reloadData() {
        // Remove old views
        for view in itemViews.values {
            view.superview?.removeFromSuperview()
        }
        
        // get number of items and placeholders
        numberOfVisibleItems = 0
        numberOfItems = dataSource.numberOfItemsInCarousel(carousel: self)
        numberOfPlaceholders = dataSource.numberOfPlaceholders(in: self)
        
        // reset view pools
        itemViews = [:]
        itemViewPool = Set()
        placeholderViewPool = Set()
        
        // layout views
        setNeedsLayout()
        
        // fix scroll offset
        if numberOfItems > 0 && scrollOffset < 0.0 {
            scrollToItem(index: 0, animated: numberOfPlaceholders > 0)
        }
    }
    
    func indexOfItemViewOrSubviews(touchedView: UIView) -> Int {
        guard let index = indexOfItemView(view: touchedView) else {
            return .zero
        }
        
        if index != .max && touchedView != contentView, let targetViewSuperView = touchedView.superview {
            return indexOfItemViewOrSubviews(touchedView: targetViewSuperView)
        }
        
        return index
    }
    
    public func offsetForItem(index: Int) -> CGFloat {
        // Calculate relative position
        var currentOffset = CGFloat(index) - scrollOffset
        let currentNumberOfItems = CGFloat(numberOfItems)
        
        if isWrapEnabled {
            if currentOffset > currentNumberOfItems / 2.0 {
                currentOffset -= currentNumberOfItems
            } else if currentOffset < -(currentNumberOfItems / 2.0) {
                currentOffset += currentNumberOfItems
            }
        }
        
#if os(macOS)
        if isVertical {
            currentOffset *= -1
        }
#endif
        
        return currentOffset
    }
    
    func containView(_ targetView: UIView) -> UIView {
        
        // Set item width
        if itemWidth == .zero {
            itemWidth = isVertical ? targetView.bounds.size.height : targetView.bounds.size.width
        }
        
        // Set Container Frame
        var frame = targetView.bounds
        frame.size.width = isVertical ? frame.size.width : itemWidth
        frame.size.height = isVertical ? itemWidth : frame.size.height
        let containerView = UIView()
        
        //if os(macOS)
        //clipping works differently on Mac OS
        // [containerView setBoundsSize:view.frame.size];
        
        frame = targetView.frame
        frame.origin.x = (containerView.bounds.size.width - frame.size.width) / 2.0
        frame.origin.y = (containerView.bounds.size.height - frame.size.height) / 2.0
        targetView.frame = frame
        containerView.addSubview(targetView)
        containerView.layer.opacity = .zero
        
        return containerView
    }
    
    public func itemView(at point: CGPoint) -> UIView? {
        let views = itemViews.values.sorted { viewOne, viewTwo in
            return compareViewDepth(viewOne: viewOne, viewTwo: viewTwo, in: self) == .orderedAscending
        }.reversed()
        
        for currentView in views {
            if currentView.superview?.layer.hitTest(point) != nil {
                return currentView
            }
        }
        
        return nil
    }
    
    func removeView(index: Int) {
        var newItemViews: [Int : UIView] = [:]
        
        for number in indexesForVisibleItems {
            if number < index {
                newItemViews[number] = itemViews[number]
            } else if number > index {
                newItemViews[number - 1] = itemViews[number]
            }
        }
        
        itemViews = newItemViews
    }
    
    public func removeItem(index: Int, animated: Bool) {
        let clampedIndex = clampedIndex(index: index)
        let itemView = itemView(index: clampedIndex)

        if animated {
            UIView.animate(withDuration: 0.1, animations: {
                itemView.superview?.layer.opacity = 0.0
            }, completion: { _ in
                self.queueItemView(view: itemView)
                itemView.superview?.removeFromSuperview()
                
                UIView.animate(withDuration: self.insertDurationDefault,
                               delay: 0.1,
                               options: [],
                               animations: { [weak self] in
                    
                    guard let self else { return }
                    self.removeView(index: index)
                    self.numberOfItems -= 1
                    self.isWrapEnabled = self.valueForOption(option: .wrap, defaultValue: CGFloat(self.isWrapEnabled.hashValue)) != .zero
                    self.updateNumberOfVisibleItems()
                    self.scrollOffset = CGFloat(self.currentItemIndex())
                    self.didScroll()
                }, completion: { _ in
                    self.depthSortViews()
                })
            })

        } else {
            pushAnimationState(enabled: false)
            queueItemView(view: itemView)
            itemView.superview?.removeFromSuperview()
            removeView(index: clampedIndex)
            numberOfItems -= 1
            isWrapEnabled = valueForOption(option: .wrap, defaultValue: CGFloat(isWrapEnabled.hashValue)) != 0
            scrollOffset = CGFloat(currentItemIndex())
            didScroll()
            depthSortViews()
            popAnimationState()
        }
    }
    
    public func insertItem(index: Int, animated: Bool) {
        
        var index = index
        numberOfItems += 1
        
        isWrapEnabled = valueForOption(option: .wrap, defaultValue: CGFloat(isWrapEnabled.hashValue)) != 0
        updateNumberOfVisibleItems()
        
        index = clampedIndex(index: index)
        // TO CHECK: Checar si se pasa una vista nueva o si se debe pasar nil
        insertView(view: UIView(), index: index)
        loadView(at: index)
        
        if abs(itemWidth) < floatErrorMarginDefault {
            updateItemWidth()
        }
        
        if animated {
#if os(iOS)
            
            UIView.animate(withDuration: insertDurationDefault,
                           animations: {
                self.transformItemViews()
            }, completion: { _ in
                self.didScroll()
            })
#else
            /*
             [NSAnimationContext beginGrouping];
             [[NSAnimationContext currentContext] setAllowsImplicitAnimation:YES];
             [CATransaction begin];
             [CATransaction setAnimationDuration:INSERT_DURATION];
             [CATransaction setCompletionBlock:^{
             [self didScroll];
             }];
             [self transformItemViews];
             [CATransaction commit];
             [NSAnimationContext endGrouping];
             */
#endif
        } else {
            pushAnimationState(enabled: false)
            didScroll()
            popAnimationState()
        }
        
        if scrollOffset < .zero {
            scrollToItem(index: .zero, animated: animated && numberOfPlaceholders > .zero)
        }
    }
    
    func insertView(view: UIView, index: Int) {
        var newItemViews: [Int : UIView] = [:]
        
        for currentIndex in indexesForVisibleItems {
            if currentIndex < index {
                newItemViews[currentIndex] = itemViews[currentIndex]
            } else {
                newItemViews[currentIndex + 1] = itemViews[currentIndex]
            }
        }
        
        // TO CHECK this might be erroneous
        newItemViews[index] = view
        itemViews = newItemViews
    }
    
    public func reloadItem(index: Int, animated: Bool) {
        // get container view
        if let containerView = itemViews[index]?.superview {
            if animated {
                // fade transition
                let transition = CATransition()
                transition.duration = insertDurationDefault
                transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                transition.type = .fade
                containerView.layer.add(transition, forKey: nil)
            }
            
            // reload view
            loadView(at: index, containerView: containerView)
        }
    }
    
    // MARK: ANIMATION
    func startAnimation() {
        if timer == nil {
            timer = Timer(timeInterval: 1.0/60.0,
                          target: self,
                          selector: #selector(step),
                          userInfo: nil,
                          repeats: true)
            
            if let timer = timer {
                RunLoop.main.add(timer, forMode: .default)
                
#if os(iOS)
                RunLoop.main.add(timer, forMode: .tracking)
#endif
            }
        }
    }
    
    func stopAnimation() {
        timer?.invalidate()
        timer = nil
    }
    
    func startDecelerating() {
        var distance = decelerationDistance
        startOffset = scrollOffset
        endOffset = startOffset + distance
        
        if isPagingEnabled {
            if distance > 0.0 {
                endOffset = ceil(startOffset)
            } else {
                endOffset = floor(startOffset)
            }
        } else if stopAtItemBoundary {
            if distance > 0.0 {
                endOffset = ceil(endOffset)
            } else {
                endOffset = floor(endOffset)
            }
        }
        
        if !isWrapEnabled {
            if bounces {
                endOffset = max(-bounceDistance, min(CGFloat(numberOfItems) - 1.0 + bounceDistance, endOffset))
            } else {
                endOffset = clampedOffset(offset: endOffset)
            }
        }
        
        distance = endOffset - startOffset
        
        startTime = CACurrentMediaTime()
        scrollDuration = abs(distance) / abs(0.5 * startVelocity)
        
        if distance != 0.0 {
            isDecelerating = true
            startAnimation()
        }
    }
    
    func easeInOut(_ time: CGFloat) -> CGFloat {
        if time < 0.5 {
            return 0.5 * pow(time * 2.0, 3.0)
        } else {
            return 0.5 * pow(time * 2.0 - 2.0, 3.0) + 1.0
        }
    }
    
    func easeOutBack(_ t: CGFloat) -> CGFloat {
        let s: CGFloat = 1.70158
        return 1 + (t - 1) * (t - 1) * ((s + 1) * (t - 1) + s)
    }
    
    @objc func step() {
        pushAnimationState(enabled: false)
        let currentTime = CACurrentMediaTime()
        var delta = currentTime - lastTime
        lastTime = currentTime
        
        if isScrolling && !isDragging {
            let time = min(1.0, (currentTime - startTime) / scrollDuration)
            delta = easeOutBack(CGFloat(time))
            scrollOffset = startOffset + (endOffset - startOffset) * delta
            didScroll()
            
            if time >= 1.0 {
                isScrolling = false
                depthSortViews()
                pushAnimationState(enabled: true)
                delegate?.didEndScrollingAnimation(carousel: self)
                popAnimationState()
            }
            
        } else if isDecelerating {
            let time = min(scrollDuration, currentTime - startTime)
            let acceleration = -startVelocity / scrollDuration
            let distance = startVelocity * time + 0.5 * acceleration * pow(time, 2.0)
            scrollOffset = startOffset + distance
            didScroll()
            
            if abs(time - scrollDuration) < floatErrorMarginDefault {
                isDecelerating = false
                pushAnimationState(enabled: true)
                delegate?.didEndDecelerating(carousel: self)
                popAnimationState()
                
                if (scrollToItemBoundary || abs(scrollOffset - clampedOffset(offset: scrollOffset)) > floatErrorMarginDefault) && autoscroll == 0 {
                    if abs(scrollOffset - CGFloat((currentItemIndex()))) < floatErrorMarginDefault {
                        scrollToItem(index: currentItemIndex(), duration: 0.01)
                    } else {
                        scrollToItem(index: currentItemIndex(), animated: true)
                    }
                } else {
                    var difference = round(scrollOffset) - scrollOffset
                    if difference > 0.5 {
                        difference -= 1.0
                    } else if difference < -0.5 {
                        difference += 1.0
                    }
                    toggleTime = currentTime - maxToggleDurationDefault * abs(difference)
                    toggle = max(-1.0, min(1.0, -difference))
                }
            }
            
        } else if autoscroll != 0 && !isDragging {
            scrollOffset = clampedOffset(offset: scrollOffset - CGFloat(delta) * autoscroll)
            
        } else if abs(toggle) > floatErrorMarginDefault {
            var toggleDuration: TimeInterval = startVelocity != 0 ?
            min(1.0, max(0.0, 1.0 / abs(startVelocity))) : 1.0
            toggleDuration = minToggleDurationDefault + (maxToggleDurationDefault - minToggleDurationDefault) * toggleDuration
            let time = min(1.0, (currentTime - toggleTime) / toggleDuration)
            delta = easeOutBack(CGFloat(time))
            toggle = toggle < 0 ? delta - 1.0 : 1.0 - delta
            didScroll()
            
        } else if autoscroll == 0 {
            stopAnimation()
        }
        
        popAnimationState()
    }
    
    @objc func didScroll() {
        if isWrapEnabled || !bounces {
            scrollOffset = clampedOffset(offset: scrollOffset)
        } else {
            let minValue = -bounceDistance
            let maxValue = CGFloat(max(numberOfItems - 1, .zero)) + bounceDistance
            
            if scrollOffset < minValue {
                scrollOffset = minValue
                startVelocity = .zero
            } else if scrollOffset > maxValue {
                scrollOffset = maxToggleDurationDefault
                startVelocity = .zero
            }
        }
        
        // check if index has changed
        let difference = minScrollDistance(from: currentItemIndex(),
                                           to: previousItemIndex)
        if difference != 0 {
            toggleTime = CACurrentMediaTime()
            toggle = CGFloat(max(-1, min(1, difference)))
            
            #if os(macOS)
            if vertical {
                // invert toggle
                toggle = -toggle
            }
            #endif
            
            startAnimation()
        }

        loadUnloadViews()
        transformItemViews()

        // notify delegate of offset change
        if abs(scrollOffset - previousScrollOffset) > floatErrorMarginDefault {
            pushAnimationState(enabled: true)
            delegate?.carouselDidScroll(self)
            popAnimationState()
        }

        // notify delegate of index change
        if previousItemIndex != currentItemIndex() {
            pushAnimationState(enabled: true)
            delegate?.carouselCurrentItemIndexDidChange(self)
            popAnimationState()
        }

        // update previous index
        previousScrollOffset = scrollOffset
        previousItemIndex = currentItemIndex()
        depthSortViews()
    }

    
    open override func didMoveToSuperview() {
        super.didMoveToSuperview()
        if self.superview != nil {
            startAnimation()
        } else {
            stopAnimation()
        }
    }
}

// MARK: UIGestureRecognizerDelegate
extension iCarouselView: UIGestureRecognizerDelegate {
    open override func gestureRecognizerShouldBegin(_ gesture: UIGestureRecognizer) -> Bool {
        if let panGesture = gesture as? UIPanGestureRecognizer {
            let translation = panGesture.translation(in: self)
            
            if ignorePerpendicularSwipes {
                if isVertical {
                    return abs(translation.x) <= abs(translation.y)
                } else {
                    return abs(translation.x) >= abs(translation.y)
                }
            }
        }
        
        return true
    }
}

// MARK: Gesture and Taps for IOS
extension iCarouselView {
    func viewOrSuperview(_ view: UIView?, implements selector: Selector) -> Bool {
        guard let view = view, view !== contentView else {
            return false
        }

        var viewClass: AnyClass? = Swift.type(of: view)
        
        while let cls = viewClass, cls != UIView.self {
            var methodCount: UInt32 = 0
            if let methods = class_copyMethodList(cls, &methodCount) {
                for i in 0..<Int(methodCount) {
                    let method = methods[i]
                    if method_getName(method) == selector {
                        free(methods)
                        return true
                    }
                }
                free(methods)
            }
            viewClass = class_getSuperclass(cls)
        }

        return viewOrSuperview(view.superview, implements: selector)
    }
    
    func viewOrSuperview<T: UIView>(_ view: UIView?, ofType type: T.Type) -> T? {
        guard let view = view, view !== contentView else {
            return nil
        }
        
        if let matchedView = view as? T {
            return matchedView
        }
        
        return viewOrSuperview(view.superview, ofType: type)
    }
    
    public func gestureRecognizer(_ gesture: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if isScrollEnabled {
            isDragging = false
            isScrolling = false
            isDecelerating = false
        }

        if gesture is UITapGestureRecognizer {
            guard let touchedView = touch.view else {
                print("ALV")
                return false
            }
            // handle tap
            var index = indexOfItemViewOrSubviews(touchedView: touchedView)
            
            if index == NSNotFound && centerItemWhenSelected {
                index = indexOfItemViewOrSubviews(touchedView: touch.view?.subviews.last ?? UIView())
            }

            if index != NSNotFound {
                if viewOrSuperview(touch.view, implements: #selector(UIView.touchesBegan(_:with:))) {
                    return false
                }
            }

        } else if gesture is UIPanGestureRecognizer {
            if !isScrollEnabled {
                return false
            } else if viewOrSuperview(touch.view, implements: #selector(UIView.touchesMoved(_:with:))) {
                
                if let scrollView = viewOrSuperview(touch.view, ofType: UIScrollView.self) {
                    return !scrollView.isScrollEnabled ||
                           (isVertical && scrollView.contentSize.height <= scrollView.frame.size.height) ||
                           (!isVertical && scrollView.contentSize.width <= scrollView.frame.size.width)
                }

                // TO IMPROVE, podemos usar view is UIControl
                if viewOrSuperview(touch.view, ofType: UIButton.self) != nil {
                    return true
                }

                return false
            }
        }

        return true
    }
    
    @objc func didTap(_ tapGesture: UITapGestureRecognizer) {
        // Check for tapped view
        let location = tapGesture.location(in: contentView)
        guard let tappedItemView = itemView(at: location) else { return }
        
        guard let index = indexOfItemView(view: tappedItemView) else { return }
//        let index = tappedItemView.flatMap { indexOfItemView(view: $0) } ?? NSNotFound

        if index != NSNotFound {
            if delegate == nil || delegate?.carousel(self, shouldSelectItemIndex: index) == true {
                if (index != currentItemIndex() && centerItemWhenSelected) ||
                   (index == currentItemIndex() && scrollToItemBoundary) {
                    scrollToItem(index: index, animated: true)
                }
                delegate?.carousel(self, didSelectItemIndex: index)
            } else if isScrollEnabled && scrollToItemBoundary && autoscroll != 0 {
                scrollToItem(index: currentItemIndex(), animated: true)
            }
        } else {
            scrollToItem(index: currentItemIndex(), animated: true)
        }
    }
    
    @objc func didPan(_ panGesture: UIPanGestureRecognizer) {
        guard isScrollEnabled, numberOfItems > 0 else { return }

        switch panGesture.state {
        case .began:
            isDragging = true
            isScrolling = false
            isDecelerating = false
            previousTranslation = isVertical ?
                panGesture.translation(in: self).y :
                panGesture.translation(in: self).x

            delegate?.willBeginDragging(carousel: self)

        case .ended, .cancelled, .failed:
            isDragging = false
            didDrag = true

            if shouldDecelerate {
                didDrag = false
                startDecelerating()
            }

            pushAnimationState(enabled: true)
            delegate?.didEndDragging(carousel: self, willDecelerate: isDecelerating)
            popAnimationState()

            if !isDecelerating {
                if (scrollToItemBoundary || abs(scrollOffset - clampedOffset(offset: scrollOffset)) > floatErrorMarginDefault) && autoscroll == 0 {
                    
                    if abs(scrollOffset - CGFloat(currentItemIndex())) < floatErrorMarginDefault {
                        scrollToItem(index: currentItemIndex(), duration: 0.01)
                    } else if shouldScroll {
                        let direction = Int(startVelocity / abs(startVelocity))
                        scrollToItem(index: currentItemIndex() + direction, animated: true)
                    } else {
                        scrollToItem(index: currentItemIndex(), animated: true)
                    }
                    
                } else {
                    depthSortViews()
                }
            } else {
                pushAnimationState(enabled: true)
                delegate?.willBeginDecelerating(carousel: self)
                popAnimationState()
            }

        case .changed:
            let translation = isVertical ?
                panGesture.translation(in: self).y :
                panGesture.translation(in: self).x
            let velocity = isVertical ?
                panGesture.velocity(in: self).y :
                panGesture.velocity(in: self).x

            var factor: CGFloat = 1.0
            if !isWrapEnabled && bounces {
                factor = 1.0 - min(abs(scrollOffset - clampedOffset(offset: scrollOffset)), bounceDistance) / bounceDistance
            }

            startVelocity = -velocity * factor * scrollSpeed / itemWidth
            scrollOffset -= (translation - previousTranslation) * factor * offsetMultiplier / itemWidth
            previousTranslation = translation
            didScroll()

        case .possible:
            // Do nothing
            break

        @unknown default:
            break
        }
    }
    
}

// MARK: TODO Mouse Dragging on Mac OS
