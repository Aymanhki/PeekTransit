import SwiftUI
import MapKit

struct LiveIndicator: View {
    @State private var isAnimating = false
    let isAnimatingEnabled: Bool
    
    init(isAnimating: Bool) {
        self.isAnimatingEnabled = isAnimating
    }
    
    var body: some View {
        ZStack {
            if isAnimatingEnabled {
                ForEach(0..<1) { i in
                    Circle()
                        .stroke(Color.red.opacity(0.5), lineWidth: 2)
                        .scaleEffect(isAnimating ? 2 : 1)
                        .opacity(isAnimating ? 0 : 1)
                        .animation(
                            .easeOut(duration: 1.5)
                            .repeatForever(autoreverses: false)
                            .delay(Double(i) * 1),
                            value: isAnimating
                        )
                }
            }
            Circle()
                .fill(isAnimatingEnabled ? Color.red : Color.blue)
                .frame(width: 8, height: 8)
        }
        .frame(width: 24, height: 24)
        .onAppear {
            isAnimating = isAnimatingEnabled
        }
        .onChange(of: isAnimatingEnabled) { newValue in
            isAnimating = newValue
        }
    }
}
