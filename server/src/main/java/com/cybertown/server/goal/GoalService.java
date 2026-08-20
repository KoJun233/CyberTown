package com.cybertown.server.goal;

import com.cybertown.server.resident.ResidentService;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class GoalService {

    private final JdbcTemplate jdbcTemplate;
    private final ResidentService residentService;
    private final ObjectMapper objectMapper;
    private final ZoneId townZone;

    public GoalService(JdbcTemplate jdbcTemplate, ResidentService residentService, ObjectMapper objectMapper,
            @Value("${cybertown.town-zone:Asia/Shanghai}") String townZone) {
        this.jdbcTemplate = jdbcTemplate;
        this.residentService = residentService;
        this.objectMapper = objectMapper;
        this.townZone = ZoneId.of(townZone);
    }

    @Transactional
    public GoalView setGoal(String accountId, String instruction, List<String> constraints) {
        if (instruction == null || instruction.isBlank() || instruction.length() > 500) {
            throw new IllegalArgumentException("目标需要 1–500 个字符");
        }
        String residentId = residentService.getForAccount(accountId).id();
        String townDate = LocalDate.now(townZone).toString();
        jdbcTemplate.update("DELETE FROM daily_goal WHERE resident_id = ? AND town_date = ?", residentId, townDate);
        Instant now = Instant.now();
        List<String> normalizedConstraints = constraints == null
                ? List.of()
                : constraints.stream().limit(2).toList();
        String safeConstraints = toJson(normalizedConstraints);
        String goalId = UUID.randomUUID().toString();
        jdbcTemplate.update("""
                INSERT INTO daily_goal(
                    id, resident_id, town_date, raw_instruction, structured_goal,
                    constraints_json, created_at, expires_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """, goalId, residentId, townDate, instruction.trim(), instruction.trim(), safeConstraints,
                now.toString(), now.plus(7, ChronoUnit.DAYS).toString());
        return new GoalView(goalId, townDate, instruction.trim(), normalizedConstraints);
    }

    private String toJson(Object value) {
        try {
            return objectMapper.writeValueAsString(value);
        } catch (JsonProcessingException exception) {
            throw new IllegalStateException("无法序列化目标限制", exception);
        }
    }

    public record GoalView(String id, String townDate, String instruction, List<String> constraints) {}
}
