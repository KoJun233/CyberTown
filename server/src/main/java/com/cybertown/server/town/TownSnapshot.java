package com.cybertown.server.town;

import com.cybertown.server.resident.ResidentView;
import java.util.List;

public record TownSnapshot(
        List<TownResident> residents,
        List<TownBubble> bubbles,
        String serverTime,
        String townDate,
        String townTime,
        String timeOfDay,
        ResidentView resident) {

    public record TownResident(
            String id,
            String displayName,
            int appearanceSeed,
            double posX,
            double posY,
            boolean current) {}

    public record TownBubble(
            String id,
            String residentId,
            String displayName,
            String message,
            String expiresAt) {}
}
