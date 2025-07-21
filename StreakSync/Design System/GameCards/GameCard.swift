import SwiftUI

/// Individual game card component
//struct GameCard: View {
//    let game: Game
//    let streak: GameStreak?
//    let todayResult: GameResult?
//    let onTap: () -> Void
//    
//    @State private var isPressed = false
//    @Environment(\.colorScheme) private var colorScheme
//    
//    private var gradientColors: [Color] {
//        switch game.name.lowercased() {
//        case "wordle":
//            return colorScheme == .dark ?
//                [Color(hex: "047857"), Color(hex: "10B981"), Color(hex: "059669"), Color(hex: "065F46")] :
//                [Color(hex: "6EE7B7"), Color(hex: "34D399"), Color(hex: "10B981"), Color(hex: "059669")]
//            
//        case "quordle":
//            return colorScheme == .dark ?
//                [Color(hex: "1E3A8A"), Color(hex: "2563EB"), Color(hex: "1E40AF"), Color(hex: "3730A3")] :
//                [Color(hex: "3B82F6"), Color(hex: "93C5FD"), Color(hex: "DBEAFE"), Color(hex: "EFF6FF")]
//            
//        case "nerdle":
//            return colorScheme == .dark ?
//                [Color(hex: "4C1D95"), Color(hex: "7C3AED"), Color(hex: "6D28D9"), Color(hex: "5B21B6")] :
//                [Color(hex: "A78BFA"), Color(hex: "C4B5FD"), Color(hex: "DDD6FE"), Color(hex: "EDE9FE")]
//                
//        case "heardle":
//            return colorScheme == .dark ?
//                [Color(hex: "831843"), Color(hex: "DB2777"), Color(hex: "BE185D"), Color(hex: "9D174D")] :
//                [Color(hex: "EC4899"), Color(hex: "F9A8D4"), Color(hex: "FCE7F3"), Color(hex: "FDF2F8")]
//            
//        default:
//            return colorScheme == .dark ?
//                [Color.gray, Color.gray.opacity(0.7)] :
//                [Color.blue, Color.blue.opacity(0.3)]
//        }
//    }
//    
//    var body: some View {
//        ZStack {
//            // Glass background layer
//            RoundedRectangle(cornerRadius: GameCardDimensions.cornerRadius)
//                .fill(.ultraThinMaterial)
//                .glassEffect(type: .medium)
//            
//            // Optimized gradient overlay
//            LinearGradient(
//                colors: gradientColors,
//                startPoint: .topLeading,
//                endPoint: .bottomTrailing
//            )
//            .opacity(0.7)
//            .clipShape(RoundedRectangle(cornerRadius: GameCardDimensions.cornerRadius))
//            
//            // Content container
//            VStack(spacing: 0) {
//                // Top section with icon and title
//                cardHeader
//                
//                Spacer()
//                
//                // Middle section with streak info
//                streakSection
//                
//                Spacer()
//                
//                // Bottom section with CTA
//                cardFooter
//            }
//            .padding(GameCardDimensions.padding)
//        }
//        .frame(width: GameCardDimensions.width, height: GameCardDimensions.height)
//        .scaleEffect(isPressed ? 0.95 : 1.0)
//        .shadow(color: gradientColors[0].opacity(0.2), radius: 10, x: 0, y: 5)
//        .onTapGesture {
//            withAnimation(.easeInOut(duration: 0.1)) {
//                isPressed = true
//            }
//            
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
//                withAnimation(.easeInOut(duration: 0.1)) {
//                    isPressed = false
//                }
//                onTap()
//            }
//        }
//    }
    
import SwiftUI

/// Individual swipeable game card
struct GameCard: View {
    let game: Game
    let streak: GameStreak?
    let todayResult: GameResult?
    let index: Int
    let currentIndex: Int
    let dragOffset: CGFloat
    let cardWidth: CGFloat
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Animation Calculations
    private var offset: CGFloat {
        let baseOffset = CGFloat(index - currentIndex) * (cardWidth + 20)
        return baseOffset + dragOffset
    }

    private var scale: CGFloat {
        let distance = abs(CGFloat(index - currentIndex))
        return 1.0 - (distance * 0.1)
    }

    private var opacity: Double {
        let distance = abs(CGFloat(index - currentIndex))
        return distance > 2 ? 0.5 : 1.0
    }

    // MARK: - Colors
    private var gradientColors: [Color] {
        switch game.name.lowercased() {
        case "wordle":
            return colorScheme == .dark
                ? [Color(hex: "047857"), Color(hex: "10B981"), Color(hex: "059669"), Color(hex: "065F46")]
                : [Color(hex: "6EE7B7"), Color(hex: "34D399"), Color(hex: "10B981"), Color(hex: "059669")]
        case "quordle":
            return colorScheme == .dark
                ? [Color(hex: "1E3A8A"), Color(hex: "2563EB"), Color(hex: "1E40AF"), Color(hex: "3730A3")]
                : [Color(hex: "3B82F6"), Color(hex: "93C5FD"), Color(hex: "DBEAFE"), Color(hex: "EFF6FF")]
        case "nerdle":
            return colorScheme == .dark
                ? [Color(hex: "4C1D95"), Color(hex: "7C3AED"), Color(hex: "6D28D9"), Color(hex: "5B21B6")]
                : [Color(hex: "A78BFA"), Color(hex: "C4B5FD"), Color(hex: "DDD6FE"), Color(hex: "EDE9FE")]
        case "heardle":
            return colorScheme == .dark
                ? [Color(hex: "831843"), Color(hex: "DB2777"), Color(hex: "BE185D"), Color(hex: "9D174D")]
                : [Color(hex: "EC4899"), Color(hex: "F9A8D4"), Color(hex: "FCE7F3"), Color(hex: "FDF2F8")]
        default:
            return colorScheme == .dark
                ? [Color.gray, Color.gray.opacity(0.7)]
                : [Color.blue, Color.blue.opacity(0.3)]
        }
    }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            cardHeader
            Spacer()
            streakSection
            Spacer()
            cardFooter
        }
        .padding()
        .frame(width: cardWidth, height: 200)
        .background(
            LinearGradient(colors: gradientColors,
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .clipShape(RoundedRectangle(cornerRadius: 20))
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .scaleEffect(scale)
        .opacity(opacity)
        .offset(x: offset)
        .zIndex(index == currentIndex ? 1 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentIndex)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: dragOffset)
        .onTapGesture(perform: onTap)
    }

    // MARK: - Card Header
    private var cardHeader: some View {
        HStack(alignment: .top) {
            GameIcon(
                icon: game.iconSystemName,
                backgroundColor: gradientColors[0],
                size: 44
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(game.displayName)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }

            Spacer()

            if todayResult != nil {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.green)
            }
        }
    }

    // MARK: - Streak Section
    private var streakSection: some View {
        Group {
            if let streak = streak {
                VStack(spacing: 20) {
                    HStack(spacing: 8) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.orange, .red],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Text("\(streak.currentStreak)")
                            .font(.system(size: 64, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }

                    Text("Day Streak")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)

                    ProgressView(value: Double(streak.currentStreak % 7), total: 7)
                        .tint(gradientColors[0])
                        .scaleEffect(y: 2)

                    Text("Next milestone: \(((streak.currentStreak / 7) + 1) * 7) days")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)

                    HStack(spacing: 30) {
                        VStack {
                            Text("\(streak.totalGamesPlayed)")
                                .font(.system(size: 24, weight: .bold))
                            Text("Played")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }

                        VStack {
                            Text("\(Int(streak.completionRate * 100))%")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.green)
                            Text("Success")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }

                        VStack {
                            Text("\(streak.maxStreak)")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(gradientColors[0])
                            Text("Best")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("Start Playing")
                        .font(.system(size: 24, weight: .bold))

                    Text("Begin your streak journey")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Card Footer
    private var cardFooter: some View {
        HStack {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 18))
                .foregroundColor(.secondary)

            Text("View Details")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.secondary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.top, 8)
    }
}
