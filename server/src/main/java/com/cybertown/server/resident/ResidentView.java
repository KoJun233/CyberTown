package com.cybertown.server.resident;

public record ResidentView(
        String id,
        String displayName,
        String backgroundKey,
        int personalitySocial,
        int personalityCuriosity,
        int personalityOrder,
        int appearanceSeed,
        int coins,
        int energy,
        int mood,
        String locationKey,
        String controlMode,
        String lastActiveAt) {}
