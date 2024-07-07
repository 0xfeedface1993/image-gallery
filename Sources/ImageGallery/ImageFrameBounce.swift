//
//  File.swift
//  
//
//  Created by sonoma on 6/30/24.
//

import Foundation
import ChainBuilder

@ChainBuiler
struct ImageFrameBounce {
    let current: NormalizationLayoutState
    let next: Size
    let imageSize: Size
    
    func control() -> (Size, Overflow) {
        let size = Size.default
        let nextState = current.transform(.create(.move(next)))
        let rect = nextState.frame(with: imageSize)
        
        if rect.width <= size.width && rect.height <= size.height {
            if nextState.center.x > current.center.x {
                return (.zero, .trallingOut(nextState.center.x - current.center.x))
            }   else if nextState.center.x < current.center.x  {
                return (.zero, .leadingOut(current.center.x - nextState.center.x))
            }
            return (.zero, .none)
        }
        
        var targetOffset = next
        var offset = Overflow.none
        
        if rect.width > size.width {
            let isTrallingOut = rect.topLeading.x > 0
            let isLeadingOut = rect.topTrailling.x < size.width
            
            if isLeadingOut {
                let space = size.width - rect.topTrailling.x
                targetOffset.width += space
                offset = .leadingOut(space)
            }
            
            if isTrallingOut {
                targetOffset.width -= rect.topLeading.x
                offset = .trallingOut(rect.topLeading.x)
            }
        }   else    {
            targetOffset.width = .zero
        }
        
        if rect.height > size.height {
            let isTopOut = rect.bottomLeading.y < size.height
            let isBottomOut = rect.topLeading.y > 0
            
            if isTopOut {
                targetOffset.height += size.height - rect.bottomLeading.y
            }
            
            if isBottomOut {
                targetOffset.height -= rect.topLeading.y
            }
        }   else    {
            targetOffset.height = .zero
        }
        
        return (targetOffset, offset)
    }
}

extension ImageFrameBounce {
    enum Overflow {
        case none
        case leadingOut(Double)
        case trallingOut(Double)
    }
}
