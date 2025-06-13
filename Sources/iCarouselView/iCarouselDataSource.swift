//
//  iCarouselDataSource.swift
//
//  Created by Cristian Olmedo on 20/04/2025.
//  Adapted from iCarousel by Nick Lockwood
//
//  Licensed under the MIT License.
//  See LICENSE file in the project root for full license information.
//
import UIKit

protocol iCarouselDataSource {
    func numberOfItemsInCarousel(carousel: iCarouselView) -> Int
    func carousel(carousel: iCarouselView, viewForItemAt index: Int, reusingView: UIView?) -> UIView
    func numberOfPlaceholders(in carousel: iCarouselView) -> Int
    func carousel(_ carousel: iCarouselView, placeholderViewAt index: Int, reusing view: UIView?) -> UIView
}
