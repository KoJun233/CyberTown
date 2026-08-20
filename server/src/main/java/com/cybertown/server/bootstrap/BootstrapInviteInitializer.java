package com.cybertown.server.bootstrap;

import com.cybertown.server.common.HashingService;
import java.time.Instant;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

@Component
public class BootstrapInviteInitializer implements ApplicationRunner {

    private final JdbcTemplate jdbcTemplate;
    private final HashingService hashingService;
    private final String inviteCode;

    public BootstrapInviteInitializer(
            JdbcTemplate jdbcTemplate,
            HashingService hashingService,
            @Value("${cybertown.bootstrap-invite-code:}") String inviteCode) {
        this.jdbcTemplate = jdbcTemplate;
        this.hashingService = hashingService;
        this.inviteCode = inviteCode;
    }

    @Override
    public void run(ApplicationArguments args) {
        if (inviteCode == null || inviteCode.isBlank()) {
            return;
        }
        String hash = hashingService.sha256(inviteCode.trim());
        Integer count = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM invite_code WHERE code_hash = ?", Integer.class, hash);
        if (count != null && count == 0) {
            jdbcTemplate.update("""
                    INSERT INTO invite_code(id, code_hash, status, created_at)
                    VALUES (?, ?, 'ACTIVE', ?)
                    """, UUID.randomUUID().toString(), hash, Instant.now().toString());
        }
    }
}
