//
//  Array-extensions.swift
//  ScaleAudio
//
//  Created by Joseph Pagliaro on 2/17/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import Foundation
import Accelerate
import simd

extension Array {
    func blocks(size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

extension Array where Element == Int16  {
    func scaleToD(length:Int, smoothly:Bool) -> [Element] {
        
        guard length > 0 else {
            return []
        }
        
        let stride = vDSP_Stride(1)
        var control:[Double]
        
        if smoothly, length > self.count {
            let denominator = Double(length) / Double(self.count - 1)
            
            control = (0...length).map {
                let x = Double($0) / denominator
                return floor(x) + simd_smoothstep(0, 1, simd_fract(x))
            }
        }
        else {
            var base: Double = 0
            var end = Double(self.count - 1)
            control = [Double](repeating: 0, count: length)
            
            vDSP_vgenD(&base, &end, &control, stride, vDSP_Length(length))
        }
        
            // for interpolation samples in app init
        if control.count <= 16  { // limit to small arrays!
            print("control = \(control)")
        }
        
        var result = [Double](repeating: 0,
                              count: length)
        
        let double_array = vDSP.integerToFloatingPoint(self, floatingPointType: Double.self)
        
        vDSP_vlintD(double_array,
                    control, stride,
                    &result, stride,
                    vDSP_Length(length),
                    vDSP_Length(double_array.count))
        
        return vDSP.floatingPointToInteger(result, integerType: Int16.self, rounding: .towardNearestInteger)
    }
    
    func extract_array_channel(channelIndex:Int, channelCount:Int) -> [Int16]? {
        
        guard channelIndex >= 0, channelIndex < channelCount, self.count > 0 else { return nil }
        
        let channel_array_length = self.count / channelCount
        
        guard channel_array_length > 0 else { return nil }
        
        var channel_array = [Int16](repeating: 0, count: channel_array_length)
        
        for index in 0...channel_array_length-1 {
            let array_index = channelIndex + index * channelCount
            channel_array[index] = self[array_index]
        }
        
        return channel_array
    }
    
    func extract_array_channels(channelCount:Int) -> [[Int16]] {
        
        var channels:[[Int16]] = []
        
        guard channelCount > 0 else { return channels }
        
        for channel_index in 0...channelCount-1 {
            if let channel = self.extract_array_channel(channelIndex: channel_index, channelCount: channelCount) {
                channels.append(channel)
            }
            
        }
        
        return channels
    }
}
