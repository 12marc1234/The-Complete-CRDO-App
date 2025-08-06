//
//  UIComponents.swift
//  CRDO
//
//  Modern UI Components and Design System
//

import SwiftUI

// MARK: - Color System
extension Color {
    // Primary Colors
    static let primaryBlue = Color(red: 0.2, green: 0.6, blue: 1.0)
    static let primaryPurple = Color(red: 0.5, green: 0.3, blue: 0.9)
    static let primaryGreen = Color(red: 0.2, green: 0.8, blue: 0.4)
    
    // Background Colors
    static let backgroundPrimary = Color(red: 0.05, green: 0.05, blue: 0.08)
    static let backgroundSecondary = Color(red: 0.08, green: 0.08, blue: 0.12)
    static let backgroundTertiary = Color(red: 0.12, green: 0.12, blue: 0.16)
    static let backgroundCard = Color(red: 0.1, green: 0.1, blue: 0.14)
    
    // Accent Colors
    static let accentGold = Color(red: 1.0, green: 0.8, blue: 0.2)
    static let accentSilver = Color(red: 0.8, green: 0.8, blue: 0.9)
    static let accentBronze = Color(red: 0.8, green: 0.6, blue: 0.4)
    
    // Status Colors
    static let successGreen = Color(red: 0.2, green: 0.8, blue: 0.4)
    static let warningOrange = Color(red: 1.0, green: 0.6, blue: 0.2)
    static let errorRed = Color(red: 1.0, green: 0.3, blue: 0.3)
    static let infoBlue = Color(red: 0.2, green: 0.6, blue: 1.0)
    
    // Text Colors
    static let textPrimary = Color.white
    static let textSecondary = Color(red: 0.8, green: 0.8, blue: 0.9)
    static let textTertiary = Color(red: 0.6, green: 0.6, blue: 0.7)
    static let textDisabled = Color(red: 0.4, green: 0.4, blue: 0.5)
}

// MARK: - Gradients
extension LinearGradient {
    static let primaryGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color.primaryBlue,
            Color.primaryPurple
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let backgroundGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color.backgroundPrimary,
            Color.backgroundSecondary,
            Color.black
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let cardGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color.backgroundCard.opacity(0.8),
            Color.backgroundCard.opacity(0.6)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let glassGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color.white.opacity(0.1),
            Color.white.opacity(0.05)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Shadows
extension View {
    func modernShadow(color: Color = .black, radius: CGFloat = 8, x: CGFloat = 0, y: CGFloat = 4) -> some View {
        self.shadow(color: color.opacity(0.3), radius: radius, x: x, y: y)
    }
    
    func glassEffect() -> some View {
        self.background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .modernShadow()
        )
    }
    
    func premiumCard() -> some View {
        self.background(
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient.cardGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .modernShadow()
        )
    }
}

// MARK: - Modern Button Styles
struct ModernButtonStyle: ButtonStyle {
    let isPrimary: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isPrimary ? LinearGradient.primaryGradient : LinearGradient.glassGradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .modernShadow()
    }
}

struct ModernSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.backgroundTertiary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
            .modernShadow()
    }
}

// MARK: - Modern Text Styles
struct ModernTitle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.largeTitle)
            .fontWeight(.bold)
            .foregroundColor(.textPrimary)
    }
}

struct ModernSubtitle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.title2)
            .fontWeight(.semibold)
            .foregroundColor(.textSecondary)
    }
}

struct ModernBody: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.body)
            .fontWeight(.medium)
            .foregroundColor(.textSecondary)
    }
}

struct ModernCaption: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.textTertiary)
    }
}

// MARK: - Reusable Components
struct ModernCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(20)
            .premiumCard()
    }
}

struct ModernSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .modifier(ModernSubtitle())
                .padding(.horizontal, 20)
            
            content
        }
    }
}

struct ModernDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.1))
            .frame(height: 1)
            .padding(.horizontal, 20)
    }
}

// MARK: - Loading and Progress Components
struct ModernLoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .primaryBlue))
                .scaleEffect(1.2)
            
            Text("Loading...")
                .modifier(ModernBody())
        }
        .padding(40)
        .premiumCard()
    }
}

struct ModernProgressBar: View {
    let progress: Double
    let color: Color
    
    init(progress: Double, color: Color = .primaryBlue) {
        self.progress = progress
        self.color = color
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.backgroundTertiary)
                    .frame(height: 8)
                
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [color, color.opacity(0.7)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * progress, height: 8)
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
        }
        .frame(height: 8)
    }
}

// MARK: - Modern Navigation Bar
struct ModernNavigationBar: ViewModifier {
    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.backgroundPrimary.opacity(0.9),
                        Color.backgroundPrimary.opacity(0.7)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                ),
                for: .navigationBar
            )
    }
}

// MARK: - Modern Tab Bar
struct ModernTabBar: View {
    @Binding var selectedTab: Int
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<4) { index in
                Button(action: {
                    selectedTab = index
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tabIcon(for: index))
                            .font(.system(size: 20))
                            .foregroundColor(selectedTab == index ? .primaryBlue : .textTertiary)
                        
                        Text(tabTitle(for: index))
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(selectedTab == index ? .primaryBlue : .textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(Color.backgroundCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .modernShadow()
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
    
    private func tabIcon(for index: Int) -> String {
        switch index {
        case 0: return "house.fill"
        case 1: return "building.2.fill"
        case 2: return "person.2.fill"
        case 3: return "person.circle.fill"
        default: return "circle"
        }
    }
    
    private func tabTitle(for index: Int) -> String {
        switch index {
        case 0: return "Home"
        case 1: return "City"
        case 2: return "Friends"
        case 3: return "Profile"
        default: return ""
        }
    }
}

// MARK: - Modern Alert
struct ModernAlert: View {
    let title: String
    let message: String
    let primaryButton: String
    let secondaryButton: String?
    let primaryAction: () -> Void
    let secondaryAction: (() -> Void)?
    
    init(
        title: String,
        message: String,
        primaryButton: String,
        secondaryButton: String? = nil,
        primaryAction: @escaping () -> Void,
        secondaryAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.primaryButton = primaryButton
        self.secondaryButton = secondaryButton
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
    }
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                Text(title)
                    .modifier(ModernTitle())
                
                Text(message)
                    .modifier(ModernBody())
                    .multilineTextAlignment(.center)
            }
            
            HStack(spacing: 12) {
                if let secondaryButton = secondaryButton {
                    Button(secondaryButton) {
                        secondaryAction?()
                    }
                    .buttonStyle(ModernSecondaryButtonStyle())
                    .frame(maxWidth: .infinity)
                }
                
                Button(primaryButton) {
                    primaryAction()
                }
                .buttonStyle(ModernButtonStyle(isPrimary: true))
                .frame(maxWidth: .infinity)
            }
        }
        .padding(24)
        .premiumCard()
        .padding(20)
    }
} 