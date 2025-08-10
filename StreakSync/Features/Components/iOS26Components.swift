//
//  Components/iOS26Components.swift
//  StreakSync
//
//  Centralized iOS 26-specific UI components
//  These components are only available on iOS 26+
//

import SwiftUI

// MARK: - iOS 26 Component Library
@available(iOS 26.0, *)
enum iOS26Components {
    
    // MARK: - Text Field Styles
    struct ModernTextFieldStyle: TextFieldStyle {
        func _body(configuration: TextField<Self._Label>) -> some View {
            configuration
                .padding()
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(.quaternary, lineWidth: 0.5)
                        }
                }
        }
    }
    
    // MARK: - Material Card
    struct MaterialCard<Content: View>: View {
        let content: Content
        let cornerRadius: CGFloat
        
        init(cornerRadius: CGFloat = 20, @ViewBuilder content: () -> Content) {
            self.cornerRadius = cornerRadius
            self.content = content()
        }
        
        var body: some View {
            content
                .background {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.regularMaterial)
                        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                }
        }
    }
    
    // MARK: - Thin Material Card
    struct ThinMaterialCard<Content: View>: View {
        let content: Content
        
        init(@ViewBuilder content: () -> Content) {
            self.content = content()
        }
        
        var body: some View {
            content
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.thinMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(.quaternary, lineWidth: 0.5)
                        }
                }
        }
    }
    
    // MARK: - Hover Button
    struct HoverButton: View {
        let title: String
        let icon: String?
        let action: () -> Void
        @State private var isHovered = false
        
        init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
            self.title = title
            self.icon = icon
            self.action = action
        }
        
        var body: some View {
            Button(action: action) {
                HStack(spacing: 8) {
                    if let icon = icon {
                        Image(systemName: icon)
                            .symbolEffect(.bounce, value: isHovered)
                    }
                    Text(title)
                }
                .padding()
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isHovered ?
                            AnyShapeStyle(.thinMaterial) :
                            AnyShapeStyle(Color.clear))
                }
            }
            .hoverEffect(.lift)
            .onHover { isHovered = $0 }
        }
    }
    
    // MARK: - Settings Row
    struct SettingsRow<Destination: View>: View {
        let icon: String
        let iconColor: Color
        let title: String
        let subtitle: String?
        let showChevron: Bool
        @ViewBuilder let destination: Destination
        
        @State private var isPressed = false
        @State private var iconBounce = false
        
        var body: some View {
            NavigationLink {
                destination
            } label: {
                HStack(spacing: 12) {
                    // Animated Icon
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundStyle(iconColor)
                        .symbolEffect(.bounce, value: iconBounce)
                        .frame(width: 32, height: 32)
                        .background {
                            Circle()
                                .fill(iconColor.opacity(0.1))
                        }
                    
                    // Text Content
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.body)
                            .foregroundStyle(.primary)
                        
                        if let subtitle = subtitle {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Chevron
                    if showChevron {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .scaleEffect(isPressed ? 0.8 : 1)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .hoverEffect(.lift)
            .onTapGesture {
                iconBounce.toggle()
            }
            .scaleEffect(isPressed ? 0.98 : 1)
        }
    }
    
    // MARK: - Category Picker
    struct CategoryPicker: View {
        @Binding var selection: GameCategory
        
        var body: some View {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(GameCategory.allCases.filter { $0 != .custom }, id: \.self) { category in
                        CategoryChip(
                            category: category,
                            isSelected: selection == category
                        ) {
                            withAnimation(.smooth(duration: 0.2)) {
                                selection = category
                            }
                        }
                    }
                }
            }
        }
        
        private struct CategoryChip: View {
            let category: GameCategory
            let isSelected: Bool
            let action: () -> Void
            
            var body: some View {
                Button(action: action) {
                    HStack(spacing: 6) {
                        Image(systemName: category.iconSystemName)
                            .font(.caption)
                            .symbolEffect(.bounce, value: isSelected)
                        Text(category.displayName)
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(isSelected ? .white : .primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background {
                        if isSelected {
                            Capsule()
                                .fill(Color.accentColor)
                        } else {
                            Capsule()
                                .fill(.ultraThinMaterial)
                        }
                    }
                }
                .hoverEffect(.highlight)
            }
        }
    }
    
    // MARK: - Search Bar
    struct SearchBar: View {
        @Binding var searchText: String
        @FocusState.Binding var isFocused: Bool
        
        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .symbolEffect(.pulse, options: .repeating, value: searchText)
                
                TextField("Search games...", text: $searchText)
                    .focused($isFocused)
                    .textFieldStyle(.plain)
                    .submitLabel(.search)
                
                if !searchText.isEmpty {
                    Button {
                        withAnimation(.bouncy) {
                            searchText = ""
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .symbolEffect(.bounce, value: searchText)
                    }
                    .buttonStyle(.plain)
                    .hoverEffect(.highlight)
                }
            }
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.thinMaterial)
                    .stroke(.quaternary, lineWidth: 0.5)
            }
        }
    }
    
    // MARK: - Scroll View Modifiers
    struct ScrollViewModifiers: ViewModifier {
        @Binding var scrollPosition: ScrollPosition
        
        func body(content: Content) -> some View {
            content
                .scrollPosition($scrollPosition)
                .scrollBounceBehavior(.automatic)
                .scrollClipDisabled()
                .contentMargins(.vertical, 20, for: .scrollContent)
                .scrollIndicators(.automatic, axes: .vertical)
                .scrollDismissesKeyboard(.interactively)
                .scrollTargetLayout()
        }
    }
    
    // MARK: - Scroll Transition Modifier
    struct ScrollTransitionModifier: ViewModifier {
        var opacity: (Bool) -> Double = { $0 ? 1 : 0.8 }
        var scale: (Bool) -> Double = { $0 ? 1 : 0.95 }
        var blur: (Bool) -> Double = { $0 ? 0 : 2 }
        
        func body(content: Content) -> some View {
            content
                .scrollTransition { innerContent, phase in
                    innerContent
                        .opacity(opacity(phase.isIdentity))
                        .scaleEffect(scale(phase.isIdentity))
                        .blur(radius: blur(phase.isIdentity))
                }
        }
    }
    
    // MARK: - Achievement Card (iOS 26) - FIXED
    struct AchievementCard: View {
        let achievement: TieredAchievement
        let action: () -> Void
        @State private var isHovered = false
        @State private var showUnlockAnimation = false
        
        // Fixed: Using the correct method to get progress percentage
        private var progressPercentage: Double {
            achievement.progress.percentageToNextTier(requirements: achievement.requirements)
        }
        
        var body: some View {
            Button(action: action) {
                VStack(spacing: 12) {
                    // Icon Section
                    ZStack {
                        Circle()
                            .fill(achievement.isUnlocked ?
                                achievement.displayColor.opacity(0.15) :
                                Color(.systemGray5))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: achievement.iconSystemName)
                            .font(.title)
                            .foregroundStyle(
                                achievement.isUnlocked ?
                                achievement.displayColor :
                                Color(.systemGray3)
                            )
                            .symbolEffect(.bounce, value: showUnlockAnimation)
                    }
                    
                    // Title and Description
                    VStack(spacing: 6) {
                        Text(achievement.displayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                        
                        Text(achievement.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .padding(.horizontal, 8)
                    
                    Spacer()
                    
                    // Progress Section
                    VStack(spacing: 8) {
                        // Progress Bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(.quaternary)
                                
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                achievement.displayColor,
                                                achievement.displayColor.opacity(0.7)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geometry.size.width * progressPercentage)
                                    .animation(.smooth, value: progressPercentage)
                            }
                        }
                        .frame(height: 6)
                        
                        // Progress Text - using the actual computed property
                        Text(achievement.progressDescription)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                    }
                }
                .padding()
                .frame(height: 220)
                .frame(maxWidth: .infinity)
                .background {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.regularMaterial)
                        .overlay {
                            if achievement.isUnlocked {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(
                                        achievement.displayColor.opacity(0.2),
                                        lineWidth: 1
                                    )
                            }
                        }
                        .shadow(
                            color: achievement.isUnlocked ?
                                achievement.displayColor.opacity(0.15) :
                                .black.opacity(0.05),
                            radius: isHovered ? 12 : 8,
                            x: 0,
                            y: isHovered ? 6 : 4
                        )
                }
            }
            .buttonStyle(.plain)
            .scaleEffect(isHovered ? 1.03 : 1.0)
            .animation(.smooth(duration: 0.2), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
                if hovering && achievement.isUnlocked {
                    showUnlockAnimation = true
                }
            }
            .hoverEffect(.lift)
        }
    }
}

// MARK: - View Extensions for iOS 26
@available(iOS 26.0, *)
extension View {
    func ios26MaterialCard(cornerRadius: CGFloat = 20) -> some View {
        iOS26Components.MaterialCard(cornerRadius: cornerRadius) {
            self
        }
    }
    
    func ios26ThinMaterialCard() -> some View {
        iOS26Components.ThinMaterialCard {
            self
        }
    }
    
    func ios26ScrollTransition(
        opacity: @escaping (Bool) -> Double = { $0 ? 1 : 0.8 },
        scale: @escaping (Bool) -> Double = { $0 ? 1 : 0.95 },
        blur: @escaping (Bool) -> Double = { $0 ? 0 : 2 }
    ) -> some View {
        self.modifier(
            iOS26Components.ScrollTransitionModifier(
                opacity: opacity,
                scale: scale,
                blur: blur
            )
        )
    }
    
    func ios26ScrollViewSetup(scrollPosition: Binding<ScrollPosition>) -> some View {
        self.modifier(iOS26Components.ScrollViewModifiers(scrollPosition: scrollPosition))
    }
}
