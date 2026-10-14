package com.cybertown.server.simulation;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class SimulationService {

    private final JdbcTemplate jdbcTemplate;
    private final ObjectMapper objectMapper;
    private final AiActionPlanner aiActionPlanner;
    private final ZoneId townZone;

    public SimulationService(JdbcTemplate jdbcTemplate, ObjectMapper objectMapper, AiActionPlanner aiActionPlanner,
            @Value("${cybertown.town-zone:Asia/Shanghai}") String townZone) {
        this.jdbcTemplate = jdbcTemplate;
        this.objectMapper = objectMapper;
        this.aiActionPlanner = aiActionPlanner;
        this.townZone = ZoneId.of(townZone);
    }

    @Transactional
    public int runSlot(TimeSlot slot) {
        String townDate = LocalDate.now(townZone).toString();
        String activeAfter = Instant.now().minus(7, ChronoUnit.DAYS).toString();
        List<ResidentRow> residents = jdbcTemplate.query("""
                SELECT id, energy, mood, coins,
                       personality_social, personality_curiosity, personality_order
                FROM resident
                WHERE last_active_at >= ? AND account_id IN (
                    SELECT id FROM account WHERE status IN ('ACTIVE', 'MUTED'))
                """, (resultSet, row) -> new ResidentRow(
                resultSet.getString("id"), resultSet.getInt("energy"),
                resultSet.getInt("mood"), resultSet.getInt("coins"),
                resultSet.getInt("personality_social"), resultSet.getInt("personality_curiosity"),
                resultSet.getInt("personality_order")), activeAfter);
        int completed = 0;
        for (ResidentRow resident : residents) {
            Integer existing = jdbcTemplate.queryForObject("""
                    SELECT COUNT(*) FROM resident_action
                    WHERE resident_id = ? AND town_date = ? AND time_slot = ?
                    """, Integer.class, resident.id(), townDate, slot.name());
            if (existing != null && existing > 0) {
                continue;
            }
            String goal = jdbcTemplate.query("""
                    SELECT raw_instruction FROM daily_goal
                    WHERE resident_id = ? AND town_date = ?
                    """, resultSet -> resultSet.next() ? resultSet.getString(1) : "", resident.id(), townDate);
            String fallbackAction = chooseAction(goal, slot, resident.energy());
            String action = aiActionPlanner.chooseAction(new AiActionPlanner.PlanningRequest(
                    resident.id(), slot, goal, resident.energy(), resident.mood(), resident.coins(),
                    resident.personalitySocial(), resident.personalityCuriosity(), resident.personalityOrder()))
                    .orElse(fallbackAction);
            Outcome outcome = applyOutcome(action, resident);
            String outcomeJson = toJson(Map.of(
                    "coins", outcome.coins(),
                    "energy", outcome.energy(),
                    "mood", outcome.mood(),
                    "location", outcome.location(),
                    "narrative", outcome.narrative()));
            Instant now = Instant.now();
            String actionId = UUID.randomUUID().toString();
            jdbcTemplate.update("""
                    INSERT INTO resident_action(
                        id, resident_id, town_date, time_slot, action_type, status,
                        outcome_json, started_at, completed_at, created_at)
                    VALUES (?, ?, ?, ?, ?, 'COMPLETED', ?, ?, ?, ?)
                    """, actionId, resident.id(), townDate, slot.name(), action,
                    outcomeJson, now.toString(), now.toString(), now.toString());
            jdbcTemplate.update("""
                    UPDATE resident SET coins = ?, energy = ?, mood = ?, location_key = ?, updated_at = ?
                    WHERE id = ?
                    """, outcome.coins(), outcome.energy(), outcome.mood(), outcome.location(), now.toString(), resident.id());
            // Persist the offline action location so every client sees the same resident.
            int offset = Math.floorMod(resident.id().hashCode(), 25) - 12;
            double x = switch (outcome.location()) {
                case "workshop" -> 462;
                case "square" -> 336;
                default -> 100;
            };
            double y = "residential".equals(outcome.location()) ? 136 : 205;
            jdbcTemplate.update("""
                    UPDATE resident_presence SET pos_x = ?, pos_y = ?, updated_at = ?
                    WHERE resident_id = ?
                    """, x + offset, y, now.toString(), resident.id());
            jdbcTemplate.update("""
                    INSERT INTO event_log(
                        id, event_type, town_date, resident_ids_json,
                        canonical_facts_json, public_narrative, created_at)
                    VALUES (?, 'ACTION_COMPLETED', ?, ?, ?, ?, ?)
                    """, UUID.randomUUID().toString(), townDate, toJson(List.of(resident.id())),
                    outcomeJson, outcome.narrative(), now.toString());
            completed++;
        }
        return completed;
    }

    private String chooseAction(String rawGoal, TimeSlot slot, int energy) {
        if (energy <= 20) {
            return "REST";
        }
        String goal = rawGoal == null ? "" : rawGoal.toLowerCase(Locale.ROOT);
        if (goal.contains("赚钱") || goal.contains("工作")) return "WORK";
        if (goal.contains("休息") || goal.contains("恢复")) return "REST";
        if (goal.contains("帮助")) return "HELP";
        if (goal.contains("探索") || goal.contains("看看")) return "EXPLORE";
        if (goal.contains("交谈") || goal.contains("社交") || goal.contains("朋友")) return "TALK";
        return switch (slot) {
            case MORNING -> "EXPLORE";
            case AFTERNOON -> "WORK";
            case EVENING -> "TALK";
            case NIGHT -> "REST";
        };
    }

    private Outcome applyOutcome(String action, ResidentRow resident) {
        int coins = resident.coins();
        int energy = resident.energy();
        int mood = resident.mood();
        return switch (action) {
            case "WORK" -> new Outcome(coins + 20, clamp(energy - 20), clamp(mood - 2), "workshop", "完成了一段工作，获得 20 金币");
            case "TALK" -> new Outcome(coins, clamp(energy - 8), clamp(mood + 8), "square", "在广场与邻居聊了聊");
            case "EXPLORE" -> new Outcome(coins, clamp(energy - 12), clamp(mood + 5), "square", "探索了小镇的霓虹街道");
            case "HELP" -> new Outcome(coins, clamp(energy - 15), clamp(mood + 10), "workshop", "帮助居民处理了一件小麻烦");
            default -> new Outcome(coins, clamp(energy + 30), clamp(mood + 4), "residential", "回到住宅区好好休息");
        };
    }

    private int clamp(int value) {
        return Math.max(0, Math.min(100, value));
    }

    private String toJson(Object value) {
        try {
            return objectMapper.writeValueAsString(value);
        } catch (JsonProcessingException exception) {
            throw new IllegalStateException("无法序列化模拟结果", exception);
        }
    }

    private record ResidentRow(
            String id,
            int energy,
            int mood,
            int coins,
            int personalitySocial,
            int personalityCuriosity,
            int personalityOrder) {}

    private record Outcome(int coins, int energy, int mood, String location, String narrative) {}
}
