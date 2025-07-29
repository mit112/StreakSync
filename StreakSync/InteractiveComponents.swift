//
//  InteractiveComponents.swift
//  StreakSync
//
//  Created by MiT on 7/24/25.
//

import SwiftUI

// MARK: - Enhanced Loading Button
/// Extends existing AnimatedButton with loading state capability
struct LoadingButton: View {
    let title: String
    let icon: String?
    let style: AnimatedButtonStyle
    let isLoading: Bool
    let action: () async -> Void
    
    @State private var isExecuting = false
    
    init(
        _ title: String,
        icon: String? = nil,
        style: AnimatedButtonStyle = .primary,
        isLoading: Bool = false,
        action: @escaping () async -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.isLoading = isLoading
        self.action = action
    }
    
    var body: some View {
        Button {
            Task {
                isExecuting = true
                await action()
                isExecuting = false
            }
        } label: {
            HStack(spacing: 12) {
                if isLoading || isExecuting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.body)
                }
                
                Text(title)
                    .font(.body.weight(.medium))
                    .opacity(isLoading || isExecuting ? 0.6 : 1.0)
            }
            .foregroundStyle(style.foregroundColor)
            .frame(minHeight: 56)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(style.backgroundColor)
                    .opacity(isLoading || isExecuting ? 0.8 : 1.0)
            )
        }
        .disabled(isLoading || isExecuting)
        .pressable(
            hapticType: .buttonTap,
            scaleAmount: isLoading || isExecuting ? 1.0 : 0.95
        )
    }
}

// MARK: - Skeleton Loading View
struct SkeletonLoadingView: View {
    @State private var isAnimating = false
    let height: CGFloat
    let cornerRadius: CGFloat
    
    init(height: CGFloat = 20, cornerRadius: CGFloat = 8) {
        self.height = height
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color(.systemGray5))
            .frame(height: height)
            .overlay(
                GeometryReader { geometry in
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(.systemGray5),
                                    Color(.systemGray4),
                                    Color(.systemGray5)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * 0.3)
                        .offset(x: isAnimating ? geometry.size.width : -geometry.size.width * 0.3)
                }
                .clipped()
            )
            .onAppear {
                withAnimation(
                    Animation.linear(duration: 1.5)
                        .repeatForever(autoreverses: false)
                ) {
                    isAnimating = true
                }
            }
    }
}

// MARK: - Pull to Refresh Container
struct PullToRefreshContainer<Content: View>: View {
    @Binding var isRefreshing: Bool
    let onRefresh: () async -> Void
    @ViewBuilder let content: Content
    
    var body: some View {
        ScrollView {
            content
        }
        .refreshable {
            HapticManager.shared.trigger(.pullToRefresh)
            await onRefresh()
        }
    }
}

// MARK: - Flare Refresh Indicator
private struct FlareRefreshIndicator: View {
    let isRefreshing: Bool
    @StateObject private var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme
    
    private var gradientColors: [Color] {
        let colors = themeManager.currentTheme.colors
        let hexColors = colorScheme == .dark ? colors.gradientDark : colors.gradientLight
        return hexColors.map { Color(hex: $0) }
    }
    
    var body: some View {
        ZStack {
            if isRefreshing {
                // Animated loading state
                Image(systemName: "flame.fill")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                    .animation(
                        Animation.linear(duration: 1.0).repeatForever(autoreverses: false),
                        value: isRefreshing
                    )
            } else {
                // Standard progress view for simplicity
                ProgressView()
            }
        }
        .frame(height: 50)
    }
}

// MARK: - Animated Toggle
struct AnimatedToggle: View {
    @Binding var isOn: Bool
    let label: String
    
    var body: some View {
        Toggle(label, isOn: $isOn)
            .onChange(of: isOn) { _ in
                HapticManager.shared.trigger(.toggleSwitch)
            }
            .pressable(hapticType: .toggleSwitch, scaleAmount: 0.98)
    }
}

// MARK: - Animated Segmented Control
struct AnimatedSegmentedControl: View {
    @Binding var selection: Int
    let options: [String]
    @Namespace private var namespace
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<options.count, id: \.self) { index in
                Button {
                    withAnimation(SpringPreset.snappy) {
                        selection = index
                    }
                    HapticManager.shared.trigger(.pickerChange)
                } label: {
                    Text(options[index])
                        .font(.subheadline.weight(selection == index ? .semibold : .regular))
                        .foregroundColor(selection == index ? .white : .primary)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background {
                            if selection == index {
                                Capsule()
                                    .fill(Color.accentColor)
                                    .matchedGeometryEffect(id: "selected", in: namespace)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color(.secondarySystemBackground), in: Capsule())
    }
}

