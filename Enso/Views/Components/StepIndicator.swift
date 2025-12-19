//
//  StepIndicator.swift
//  Enso
//

import SwiftUI

struct StepIndicator: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 16) {
            // Text label
            Text("Step \(currentStep) of \(totalSteps)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            // Visual dots
            HStack(spacing: 8) {
                ForEach(1...totalSteps, id: \.self) { step in
                    Circle()
                        .fill(step <= currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 6, height: 6)
                        .scaleEffect(step == currentStep ? 1.2 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentStep)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: Capsule())
    }
}

#Preview {
    VStack(spacing: 30) {
        StepIndicator(currentStep: 1, totalSteps: 4)
        StepIndicator(currentStep: 2, totalSteps: 4)
        StepIndicator(currentStep: 3, totalSteps: 4)
        StepIndicator(currentStep: 4, totalSteps: 4)
    }
    .padding(40)
}
