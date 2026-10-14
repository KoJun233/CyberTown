package com.cybertown.server.report;

import com.cybertown.server.resident.ResidentService;
import com.cybertown.server.resident.ResidentView;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

@Service
public class ReportService {

    private final JdbcTemplate jdbcTemplate;
    private final ResidentService residentService;
    private final ZoneId townZone;
    private final ObjectMapper objectMapper;

    public ReportService(JdbcTemplate jdbcTemplate, ResidentService residentService, ObjectMapper objectMapper,
            @Value("${cybertown.town-zone:Asia/Shanghai}") String townZone) {
        this.jdbcTemplate = jdbcTemplate;
        this.residentService = residentService;
        this.objectMapper = objectMapper;
        this.townZone = ZoneId.of(townZone);
    }

    public DailyReport today(String accountId) {
        ResidentView resident = residentService.getForAccount(accountId);
        String townDate = LocalDate.now(townZone).toString();
        String goal = jdbcTemplate.query("""
                SELECT raw_instruction FROM daily_goal WHERE resident_id = ? AND town_date = ?
                """, resultSet -> resultSet.next() ? resultSet.getString(1) : null, resident.id(), townDate);
        String constraintsJson = jdbcTemplate.query("""
                SELECT constraints_json FROM daily_goal WHERE resident_id = ? AND town_date = ?
                """, resultSet -> resultSet.next() ? resultSet.getString(1) : "[]", resident.id(), townDate);
        List<String> constraints;
        try {
            constraints = objectMapper.readValue(constraintsJson, new TypeReference<List<String>>() {});
        } catch (JsonProcessingException exception) {
            throw new IllegalStateException("无法读取今日目标限制", exception);
        }
        List<ActionEntry> actions = jdbcTemplate.query("""
                SELECT time_slot, action_type, status, outcome_json, completed_at
                FROM resident_action
                WHERE resident_id = ? AND town_date = ?
                ORDER BY CASE time_slot
                    WHEN 'MORNING' THEN 1 WHEN 'AFTERNOON' THEN 2
                    WHEN 'EVENING' THEN 3 ELSE 4 END
                """, (resultSet, row) -> new ActionEntry(
                resultSet.getString("time_slot"), resultSet.getString("action_type"),
                resultSet.getString("status"), resultSet.getString("outcome_json"),
                resultSet.getString("completed_at")), resident.id(), townDate);
        return new DailyReport(townDate, resident, goal, constraints, actions);
    }

    public record DailyReport(String townDate, ResidentView resident, String goal, List<String> constraints, List<ActionEntry> actions) {}

    public record ActionEntry(String timeSlot, String actionType, String status, String outcomeJson, String completedAt) {}
}
