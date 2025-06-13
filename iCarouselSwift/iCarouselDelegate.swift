//
//  iCarouselDelegate.swift
//
//  Created by Cristian Olmedo on 20/04/2025.
//  Adapted from iCarousel by Nick Lockwood
//
//  Licensed under the MIT License.
//  See LICENSE file in the project root for full license information.
//

import Foundation
import QuartzCore

protocol iCarouselDelegate: NSObject {
    
    func willBeginScrollingAnimation(carousel: iCarouselView)
    func didEndScrollingAnimation(carousel: iCarouselView)
    func currentItemIndexDidChange(carousel: iCarouselView)
    func willBeginDragging(carousel: iCarouselView)
    func didEndDragging(carousel: iCarouselView, willDecelerate decelerate: Bool)
    func willBeginDecelerating(carousel: iCarouselView)
    func didEndDecelerating(carousel: iCarouselView)
    
    func carousel(_ carousel: iCarouselView, shouldSelectItemIndex index: Int) -> Bool
    func carousel(_ carousel: iCarouselView, didSelectItemIndex index: Int)
    func carouselCurrentItemIndexDidChange(_ carousel: iCarouselView)
    func carouselDidScroll(_ carousel: iCarouselView)

    func carouselItemWidth(carousel: iCarouselView) -> CGFloat
    func carousel(itemTransformOffset offset: CGFloat, baseTransform transform:  CATransform3D) -> CATransform3D
    func carousel(carousel: iCarouselView, valueForOption option: iCarouselOption, withDefault value: CGFloat) -> CGFloat
}
