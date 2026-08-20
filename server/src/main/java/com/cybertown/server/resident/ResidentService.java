package com.cybertown.server.resident;

import java.time.Instant;
import java.util.List;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

@Service
public class ResidentService {

    private final JdbcTemplate jdbcTemplate;

    public ResidentService(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public ResidentView getForAccount(String accountId) {
        List<ResidentView> residents = jdbcTemplate.query("""
                SELECT id, display_name, background_key,
                       personality_social, personality_curiosity, personality_order,
                       appearance_seed, coins, energy, mood, location_key, control_mode, last_active_at
                FROM resident WHERE account_id = ?
                """, (resultSet, row) -> new ResidentView(
                resultSet.getString("id"), resultSet.getString("display_name"),
                resultSet.getString("background_key"), resultSet.getInt("personality_social"),
                resultSet.getInt("personality_curiosity"), resultSet.getInt("personality_order"),
                resultSet.getInt("appearance_seed"), resultSet.getInt("coins"),
                resultSet.getInt("energy"), resultSet.getInt("mood"),
                resultSet.getString("location_key"), resultSet.getString("control_mode"),
                resultSet.getString("last_active_at")), accountId);
        ResidentView resident = residents.stream().findFirst()
                .orElseThrow(() -> new IllegalArgumentException("居民不存在"));
        jdbcTemplate.update("UPDATE resident SET last_active_at = ?, updated_at = ? WHERE id = ?",
                Instant.now().toString(), Instant.now().toString(), resident.id());
        return resident;
    }
}
