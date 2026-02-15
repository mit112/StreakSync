//
//  TierRequirementRow.swift
//  StreakSync
//
//  Row component showing tier progress with expand/collapse detail
//

import SwiftUI

struct TierRequirementRow: View {
    let requirement: TierRequirement
    let progress: AchievementProgress
    let isExpanded: Bool
    
    private var isUnlocked: Bool {
        if progress.tierUnlockDates[requirement.tier] != nil {
            return true
        }
        if let currentTier = progress.currentTier,
           currentTier.rawValue > requirement.tier.rawValue {
            return true
        }
        return false
    }
    
    private var progressToThisTier: Double {
        let currentValue = Double(progress.currentValue)
        let threshold = Double(requirement.threshold)
        return min(currentValue / threshold, 1.0)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Image.safeSystemName(requirement.tier.iconSystemName, fallback: "trophy.fill")
                    .font(.title3)
                    .foregroundStyle(isUnlocked ? requirement.tier.color : .gray)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(requirement.tier.displayName)
                        .font(.subheadline.weight(.medium))
                    
                    if isUnlocked {
                        if let unlockDate = progress.tierUnlockDates[requirement.tier] {
                            Text("Unlocked \(unlockDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Completed")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Requires \(requirement.threshold)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                if isUnlocked {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.green)
                } else {
                    CircularProgressView(
                        progress: progressToThisTier,
                        centerText: "\(progress.currentValue)/\(requirement.threshold)"
                    )
                    .frame(width: 36, height: 36)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isUnlocked ? requirement.tier.color.opacity(0.1) : Color(.systemGray6))
            )
            
            if isExpanded && !isUnlocked {
                HStack {
                    Text("Progress: \(progress.currentValue) / \(requirement.threshold)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text("\(Int(progressToThisTier * 100))%")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(requirement.tier.color)
                }
                .padding(.horizontal)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
