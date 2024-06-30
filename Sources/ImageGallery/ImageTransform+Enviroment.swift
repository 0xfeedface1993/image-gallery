//
//  ImageTargetTransform+Enviroment.swift
//  S8Blocker
//
//  Created by sonoma on 6/25/24.
//

import Foundation
import SwiftUI

extension EnvironmentValues {
    /// 用于对图片移动结束时，进行位置矫正，比如超过边界时就不进行位移，返回原始位置。
    @Entry var imageTargetTransformer: (ImageLayoutState, ImageLayoutState, Size) -> Size = { $2 }
    /// 用于对图片移动过程中，进行位置矫正，和imageTargetTransformer类似，只不过作用的是tempState
    @Entry var imageProgressTransformer: (ImageLayoutState, Size) -> Size = { $1 }
    @Entry var dargging: (ImageLayoutState, Size) -> Void = { _, _ in }
}
