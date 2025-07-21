import SwiftUI

// MARK: - Color Theme Definitions
enum ColorTheme: String, CaseIterable {
    case indigo = "Indigo Dreams"      // Current refined theme
    case aurora = "Aurora"              // Northern lights inspired
    case sunset = "Sunset"              // Warm sunset colors
    case ocean = "Ocean Depths"         // Deep sea blues
    case forest = "Forest"              // Natural greens
    case monochrome = "Monochrome"      // Elegant grayscale
    
    var colors: ThemeColors {
        switch self {
        case .indigo:
            return ThemeColors(
                backgroundLight: "F8FAFC",
                backgroundDark: "0A0E14",
                gradientLight: ["E0E7FF", "C7D2FE"],
                gradientDark: ["1E293B", "0F172A"],
                accentLight: ["4338CA", "6366F1"],
                accentDark: ["818CF8", "6366F1"],
                statOrange: ["FB923C", "F97316"],
                statGreen: ["34D399", "10B981"]
            )
            
        case .aurora:
            return ThemeColors(
                backgroundLight: "F8FAFC",
                backgroundDark: "0C0E1A",
                gradientLight: ["E0F2FE", "BAE6FD"],
                gradientDark: ["1E3A5F", "0F2942"],
                accentLight: ["0EA5E9", "06B6D4"],
                accentDark: ["38BDF8", "22D3EE"],
                statOrange: ["F59E0B", "F97316"],
                statGreen: ["10B981", "059669"]
            )
            
        case .sunset:
            return ThemeColors(
                backgroundLight: "FFFBF5",
                backgroundDark: "1A0F0A",
                gradientLight: ["FEE2E2", "FECACA"],
                gradientDark: ["451A03", "78350F"],
                accentLight: ["DC2626", "F97316"],
                accentDark: ["F87171", "FB923C"],
                statOrange: ["F59E0B", "EA580C"],
                statGreen: ["84CC16", "65A30D"]
            )
            
        case .ocean:
            return ThemeColors(
                backgroundLight: "F0F9FF",
                backgroundDark: "0A1628",
                gradientLight: ["DBEAFE", "BFDBFE"],
                gradientDark: ["1E3A8A", "1E40AF"],
                accentLight: ["2563EB", "1D4ED8"],
                accentDark: ["60A5FA", "3B82F6"],
                statOrange: ["FB923C", "F97316"],
                statGreen: ["34D399", "10B981"]
            )
            
        case .forest:
            return ThemeColors(
                backgroundLight: "F0FDF4",
                backgroundDark: "0A1F0F",
                gradientLight: ["D1FAE5", "A7F3D0"],
                gradientDark: ["064E3B", "047857"],
                accentLight: ["059669", "047857"],
                accentDark: ["34D399", "10B981"],
                statOrange: ["F59E0B", "D97706"],
                statGreen: ["10B981", "059669"]
            )
            
        case .monochrome:
            return ThemeColors(
                backgroundLight: "FAFAFA",
                backgroundDark: "0A0A0A",
                gradientLight: ["E5E5E5", "D4D4D4"],
                gradientDark: ["262626", "171717"],
                accentLight: ["404040", "525252"],
                accentDark: ["A3A3A3", "D4D4D4"],
                statOrange: ["737373", "525252"],
                statGreen: ["525252", "404040"]
            )
        }
    }
}

struct ThemeColors {
    let backgroundLight: String
    let backgroundDark: String
    let gradientLight: [String]
    let gradientDark: [String]
    let accentLight: [String]
    let accentDark: [String]
    let statOrange: [String]
    let statGreen: [String]
}

// MARK: - Theme Preview View
struct ColorThemeExplorer: View {
    @State private var selectedTheme: ColorTheme = .indigo
    @State private var colorScheme: ColorScheme = .light
    
    var body: some View {
        ZStack {
            // Background
            (colorScheme == .dark ?
                Color(hex: selectedTheme.colors.backgroundDark) :
                Color(hex: selectedTheme.colors.backgroundLight))
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.3), value: selectedTheme)
            
            VStack(spacing: 0) {
                // Header
                headerSection
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Theme selector
                        themeSelectorSection
                        
                        // Preview sections
                        previewHeader
                        previewStats
                        previewCard
                        previewTabBar
                    }
                    .padding()
                }
            }
        }
        .preferredColorScheme(colorScheme)
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            Text("Color Theme Explorer")
                .font(.largeTitle.bold())
                .padding(.top)
            
            // Dark mode toggle
            Toggle("Dark Mode", isOn: Binding(
                get: { colorScheme == .dark },
                set: { colorScheme = $0 ? .dark : .light }
            ))
            .toggleStyle(SwitchToggleStyle(tint: Color(selectedTheme.colors.accentLight[0])))
            .padding(.horizontal, 60)
        }
        .padding(.bottom)
    }
    
    // MARK: - Theme Selector
    private var themeSelectorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Theme")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ColorTheme.allCases, id: \.self) { theme in
                        ThemeButton(
                            theme: theme,
                            isSelected: selectedTheme == theme,
                            colorScheme: colorScheme
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                selectedTheme = theme
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Preview Sections
    private var previewHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Header Preview")
                .font(.caption.bold())
                .foregroundColor(.secondary)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("StreakSync")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: (colorScheme == .dark ?
                                    selectedTheme.colors.accentDark :
                                    selectedTheme.colors.accentLight)
                                .map { Color($0) },
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text("Good morning")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.8))
                }
                
                Spacer()
                
                Circle()
                    .fill(Color.primary.opacity(0.05))
                    .frame(width: 42, height: 42)
                    .overlay(
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.primary.opacity(0.6))
                    )
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.primary.opacity(0.02))
            )
        }
    }
    
    private var previewStats: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stats Preview")
                .font(.caption.bold())
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                StatPreview(
                    icon: "flame.fill",
                    value: "7",
                    label: "Active",
                    colors: selectedTheme.colors.statOrange.map { Color($0) }
                )
                
                StatPreview(
                    icon: "checkmark.circle.fill",
                    value: "3",
                    label: "Today",
                    colors: selectedTheme.colors.statGreen.map { Color($0) }
                )
            }
        }
    }
    
    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Card Preview")
                .font(.caption.bold())
                .foregroundColor(.secondary)
            
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "w.square.fill")
                        .font(.title)
                    Text("Wordle")
                        .font(.title2.bold())
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                VStack(spacing: 8) {
                    Text("5")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                    Text("Day Streak")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .frame(height: 180)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: (colorScheme == .dark ?
                        selectedTheme.colors.gradientDark :
                        selectedTheme.colors.gradientLight)
                    .map { Color($0).opacity(0.3) },
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
            )
        }
    }
    
    private var previewTabBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tab Bar Preview")
                .font(.caption.bold())
                .foregroundColor(.secondary)
            
            HStack(spacing: 0) {
                ForEach(["house.fill", "chart.line.uptrend.xyaxis", "trophy.fill", "gearshape.fill"], id: \.self) { icon in
                    VStack(spacing: 4) {
                        Image(systemName: icon)
                            .font(.system(size: 20))
                        Text(icon == "house.fill" ? "Home" : "Tab")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(
                        icon == "house.fill" ?
                            LinearGradient(
                                colors: (colorScheme == .dark ?
                                    selectedTheme.colors.accentDark :
                                    selectedTheme.colors.accentLight)
                                .map { Color($0) },
                                startPoint: .top,
                                endPoint: .bottom
                            ) :
                            LinearGradient(
                                colors: [Color.secondary.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
            )
        }
    }
}

// MARK: - Theme Button
struct ThemeButton: View {
    let theme: ColorTheme
    let isSelected: Bool
    let colorScheme: ColorScheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Color preview circles
                HStack(spacing: 4) {
                    let hexColors = [
                        theme.colors.accentLight[0],
                        theme.colors.statOrange[0],
                        theme.colors.statGreen[0]
                    ]
                    
                    ForEach(hexColors, id: \.self) { hex in
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 16, height: 16)
                    }
                }


                Text(theme.rawValue)
                    .font(.caption.bold())
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.primary.opacity(0.1) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                isSelected ? Color.primary.opacity(0.3) : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
        }
    }
}


// MARK: - Stat Preview
struct StatPreview: View {
    let icon: String
    let value: String
    let label: String
    let colors: [Color]
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.primary.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(
                            LinearGradient(colors: colors.map { $0.opacity(0.2) },
                                         startPoint: .topLeading,
                                         endPoint: .bottomTrailing),
                            lineWidth: 1
                        )
                )
        )
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        let scanner = Scanner(string: hex)
        if hex.hasPrefix("#") {
            scanner.currentIndex = hex.index(after: hex.startIndex)
        }

        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)

        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}


// MARK: - Preview
#Preview {
    ColorThemeExplorer()
}

