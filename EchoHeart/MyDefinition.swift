//
//  MyDefinition.swift
//  EchoHeart
//
//  Created by klm923 on 2025/07/02.
//

import SwiftUI

extension Color {
    static let echoPink = Color(red: 240/255, green: 98/255, blue: 146/255)
    static let echoBlue = Color(red: 129/255, green: 212/255, blue: 250/255)
    static let echoGreen = Color(red: 165/255, green: 214/255, blue: 167/255)
}


struct FatSlider: View {
    @Binding var value: Float
    var range: ClosedRange<Float>
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 12) // トラック太さ

                Capsule()
                    .fill(Color.pink).opacity(0.8)
                    .frame(width: CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound)) * geo.size.width, height: 12)

                Circle()
                    .fill(Color.white)
                    .frame(width: 30, height: 30) // つまみの大きさ
                    .offset(x: CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound)) * geo.size.width - 15)
                    .shadow(radius: 2)
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                let newX = min(max(0, gesture.location.x), geo.size.width)
                                value = Float(newX / geo.size.width) * (range.upperBound - range.lowerBound) + range.lowerBound
                            }
                    )
            }
        }
        .frame(height: 30)
//        .padding(.horizontal)
    }
}
