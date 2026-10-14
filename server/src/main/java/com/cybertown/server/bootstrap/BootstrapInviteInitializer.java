package com.cybertown.server.bootstrap;

import com.cybertown.server.common.HashingService;
import java.time.Instant;
import java.util.UUID;
import java.util.LinkedHashSet;
import java.util.Arrays;
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
    private final String inviteCodes;

    public BootstrapInviteInitializer(
            JdbcTemplate jdbcTemplate,
            HashingService hashingService,
            @Value("${cybertown.bootstrap-invite-code:}") String inviteCode,
            @Value("${cybertown.bootstrap-invite-codes:}") String inviteCodes) {
        this.jdbcTemplate = jdbcTemplate;
        this.hashingService = hashingService;
        this.inviteCode = inviteCode;
        this.inviteCodes = inviteCodes;
    }

    @Override
    public void run(ApplicationArguments args) {
        var codes = new LinkedHashSet<String>();
        if (inviteCode != null && !inviteCode.isBlank()) codes.add(inviteCode.trim());
        if (inviteCodes != null) {
            Arrays.stream(inviteCodes.split(",")).map(String::trim)
                    .filter(code -> !code.isBlank()).forEach(codes::add);
        }
        codes.forEach(this::initializeCode);
    }

    private void initializeCode(String code) {
        String hash = hashingService.sha256(code);
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
