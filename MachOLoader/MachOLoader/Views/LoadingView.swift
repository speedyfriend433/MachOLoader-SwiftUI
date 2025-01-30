//
//  LoadingView.swift
//  MachOLoader
//
//  Created by speedy on 1/30/25.
//

import SwiftUI

struct LoadingView: View {
    @Binding var isLoading: Bool
    
    var body: some View {
        if isLoading {
            ZStack {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    
                    Text("Analyzing...")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .padding(30)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black.opacity(0.6))
                        .blur(radius: 0.5)
                )
                .transition(.scale.combined(with: .opacity))
            }
            .transition(.opacity)
        }
    }
}
