package com.cybertown.server.town;

import com.cybertown.server.common.RateLimitException;
import com.cybertown.server.common.ForbiddenException;
import com.cybertown.server.resident.ResidentService;
import com.cybertown.server.town.TownSnapshot.TownBubble;
import com.cybertown.server.town.TownSnapshot.TownResident;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class TownService {

    private static final double NEARBY_RADIUS = 190.0;
    private static final Duration BUBBLE_COOLDOWN = Duration.ofSeconds(10);
    private static final Duration BUBBLE_LIFETIME = Duration.ofSeconds(18);

    private final JdbcTemplate jdbcTemplate;
    private final ResidentService residentService;
    private final ZoneId townZone;

    public TownService(JdbcTemplate jdbcTemplate, ResidentService residentService,
            @Value("${cybertown.town-zone:Asia/Shanghai}") String townZone) {
        this.jdbcTemplate = jdbcTemplate;
        this.residentService = residentService;
        this.townZone = ZoneId.of(townZone);
    }

    @Transactional
    public TownSnapshot snapshot(String accountId) {
        ResidentAnchor own = findAnchor(accountId);
        List<TownResident> residents = jdbcTemplate.query("""
                SELECT r.id, r.display_name, r.appearance_seed, p.pos_x, p.pos_y
                FROM resident r
                JOIN account a ON a.id = r.account_id
                JOIN resident_presence p ON p.resident_id = r.id
                WHERE a.status IN ('ACTIVE', 'MUTED')
                ORDER BY r.created_at, r.id
                """, (resultSet, row) -> new TownResident(
                resultSet.getString("id"),
                resultSet.getString("display_name"),
                resultSet.getInt("appearance_seed"),
                resultSet.getDouble("pos_x"),
                resultSet.getDouble("pos_y"),
                own.residentId().equals(resultSet.getString("id"))));

        double radiusSquared = NEARBY_RADIUS * NEARBY_RADIUS;
        List<TownBubble> bubbles = jdbcTemplate.query("""
                SELECT b.id, b.resident_id, r.display_name, b.message, b.expires_at
                FROM town_bubble b
                JOIN resident r ON r.id = b.resident_id
                JOIN account a ON a.id = r.account_id
                JOIN resident_presence p ON p.resident_id = r.id
                WHERE b.expires_at > ?
                  AND a.status IN ('ACTIVE', 'MUTED')
                  AND ((p.pos_x - ?) * (p.pos_x - ?) + (p.pos_y - ?) * (p.pos_y - ?)) <= ?
                ORDER BY b.created_at DESC
                LIMIT 20
                """, (resultSet, row) -> new TownBubble(
                resultSet.getString("id"),
                resultSet.getString("resident_id"),
                resultSet.getString("display_name"),
                resultSet.getString("message"),
                resultSet.getString("expires_at")),
                Instant.now().toString(), own.posX(), own.posX(), own.posY(), own.posY(), radiusSquared);
        var now = Instant.now();
        var local = now.atZone(townZone);
        int hour = local.getHour();
        String timeOfDay = hour < 6 || hour >= 22 ? "夜晚"
                : hour < 12 ? "清晨" : hour < 18 ? "午后" : "傍晚";
        return new TownSnapshot(residents, bubbles, now.toString(), local.toLocalDate().toString(),
                local.format(DateTimeFormatter.ofPattern("HH:mm")), timeOfDay,
                residentService.getForAccount(accountId));
    }

    @Transactional
    public void updatePresence(String accountId, double requestedX, double requestedY) {
        if (!Double.isFinite(requestedX) || !Double.isFinite(requestedY)) {
            throw new IllegalArgumentException("地图坐标不合法");
        }
        ResidentAnchor own = findAnchor(accountId);
        double x = Math.max(8.0, Math.min(632.0, requestedX));
        double y = Math.max(70.0, Math.min(330.0, requestedY));
        String now = Instant.now().toString();
        jdbcTemplate.update("""
                UPDATE resident_presence SET pos_x = ?, pos_y = ?, updated_at = ?
                WHERE resident_id = ?
                """, x, y, now, own.residentId());
        jdbcTemplate.update("UPDATE resident SET last_active_at = ?, updated_at = ? WHERE id = ?",
                now, now, own.residentId());
    }

    @Transactional
    public TownBubble sendBubble(String accountId, String rawMessage) {
        ResidentAnchor own = findAnchor(accountId);
        if ("MUTED".equals(own.accountStatus())) {
            throw new ForbiddenException("当前账号已被禁言，暂时无法发送气泡");
        }
        String message = normalizeMessage(rawMessage);
        List<String> recent = jdbcTemplate.query("""
                SELECT created_at FROM town_bubble
                WHERE resident_id = ?
                ORDER BY created_at DESC LIMIT 1
                """, (resultSet, row) -> resultSet.getString("created_at"), own.residentId());
        Instant now = Instant.now();
        if (!recent.isEmpty()) {
            Instant allowedAt = Instant.parse(recent.getFirst()).plus(BUBBLE_COOLDOWN);
            if (allowedAt.isAfter(now)) {
                long seconds = Math.max(1, Duration.between(now, allowedAt).toSeconds() + 1);
                throw new RateLimitException("发送太快，请等待 %d 秒".formatted(seconds));
            }
        }
        String id = UUID.randomUUID().toString();
        String expiresAt = now.plus(BUBBLE_LIFETIME).toString();
        jdbcTemplate.update("""
                INSERT INTO town_bubble(id, resident_id, message, created_at, expires_at)
                VALUES (?, ?, ?, ?, ?)
                """, id, own.residentId(), message, now.toString(), expiresAt);
        return new TownBubble(id, own.residentId(), own.displayName(), message, expiresAt);
    }

    private ResidentAnchor findAnchor(String accountId) {
        List<ResidentAnchor> residents = jdbcTemplate.query("""
                SELECT r.id, r.display_name, p.pos_x, p.pos_y, a.status
                FROM resident r
                JOIN account a ON a.id = r.account_id
                JOIN resident_presence p ON p.resident_id = r.id
                WHERE r.account_id = ? AND a.status IN ('ACTIVE', 'MUTED')
                """, (resultSet, row) -> new ResidentAnchor(
                resultSet.getString("id"),
                resultSet.getString("display_name"),
                resultSet.getDouble("pos_x"),
                resultSet.getDouble("pos_y"), resultSet.getString("status")), accountId);
        return residents.stream().findFirst()
                .orElseThrow(() -> new SecurityException("居民不存在或账号不可用"));
    }

    private String normalizeMessage(String rawMessage) {
        String message = rawMessage == null ? "" : rawMessage
                .replace('\n', ' ')
                .replace('\r', ' ')
                .trim()
                .replaceAll("\\s{2,}", " ");
        if (message.isBlank()) {
            throw new IllegalArgumentException("气泡内容不能为空");
        }
        if (message.codePointCount(0, message.length()) > 60) {
            throw new IllegalArgumentException("气泡内容最多 60 个字符");
        }
        return message;
    }

    private record ResidentAnchor(
            String residentId,
            String displayName,
            double posX,
            double posY,
            String accountStatus) {}
}
