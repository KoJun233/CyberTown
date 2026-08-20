package com.cybertown.server.auth;

import com.cybertown.server.common.HashingService;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ThreadLocalRandom;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthService {

    private static final List<String> BACKGROUNDS = List.of(
            "corporate_clerk", "repair_apprentice", "street_artist",
            "data_archivist", "courier", "traveler");

    private final JdbcTemplate jdbcTemplate;
    private final HashingService hashingService;
    private final int maxResidents;

    public AuthService(
            JdbcTemplate jdbcTemplate,
            HashingService hashingService,
            @Value("${cybertown.max-residents:20}") int maxResidents) {
        this.jdbcTemplate = jdbcTemplate;
        this.hashingService = hashingService;
        this.maxResidents = maxResidents;
    }

    @Transactional
    public AuthResult register(RegisterCommand command) {
        String username = normalizeUsername(command.username());
        if (!command.privacyAccepted()) {
            throw new IllegalArgumentException("必须同意测试与隐私说明");
        }
        if (command.inviteCode() == null || command.inviteCode().isBlank()) {
            throw new IllegalArgumentException("请输入邀请码");
        }
        Integer residents = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM resident", Integer.class);
        if (residents != null && residents >= maxResidents) {
            throw new IllegalArgumentException("小镇居民已满");
        }

        String inviteHash = hashingService.sha256(command.inviteCode().trim());
        List<String> invites = jdbcTemplate.query(
                "SELECT id FROM invite_code WHERE code_hash = ? AND status = 'ACTIVE'",
                (resultSet, row) -> resultSet.getString("id"), inviteHash);
        String inviteId = invites.stream().findFirst()
                .orElseThrow(() -> new IllegalArgumentException("邀请码无效或已使用"));

        Instant now = Instant.now();
        String accountId = UUID.randomUUID().toString();
        String residentId = UUID.randomUUID().toString();
        String recoveryCode = hashingService.recoveryCode();
        String accessToken = hashingService.randomToken(32);
        String refreshToken = hashingService.randomToken(48);
        int seed = ThreadLocalRandom.current().nextInt(1, Integer.MAX_VALUE);
        String background = BACKGROUNDS.get(Math.floorMod(seed, BACKGROUNDS.size()));
        String displayName = command.displayName() == null || command.displayName().isBlank()
                ? username
                : command.displayName().trim();

        jdbcTemplate.update("""
                INSERT INTO account(id, username, recovery_code_hash, status, privacy_accepted_at, created_at, updated_at)
                VALUES (?, ?, ?, 'ACTIVE', ?, ?, ?)
                """, accountId, username, hashingService.passwordHash(recoveryCode), now.toString(), now.toString(), now.toString());
        jdbcTemplate.update("""
                INSERT INTO resident(
                    id, account_id, display_name, background_key,
                    personality_social, personality_curiosity, personality_order,
                    appearance_seed, last_active_at, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, residentId, accountId, displayName, background,
                randomAxis(seed, 11), randomAxis(seed, 23), randomAxis(seed, 37),
                seed, now.toString(), now.toString(), now.toString());
        jdbcTemplate.update("""
                INSERT INTO access_session(
                    id, account_id, access_token_hash, refresh_token_hash,
                    access_expires_at, refresh_expires_at, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """, UUID.randomUUID().toString(), accountId,
                hashingService.sha256(accessToken), hashingService.sha256(refreshToken),
                now.plus(15, ChronoUnit.MINUTES).toString(), now.plus(30, ChronoUnit.DAYS).toString(), now.toString());
        jdbcTemplate.update("""
                UPDATE invite_code
                SET status = 'USED', used_by_account_id = ?, used_at = ?
                WHERE id = ? AND status = 'ACTIVE'
                """, accountId, now.toString(), inviteId);

        return new AuthResult(accountId, residentId, username, displayName, background,
                seed, recoveryCode, accessToken, refreshToken, 900, 2_592_000);
    }

    @Transactional
    public AuthResult recover(RecoverCommand command) {
        String username = normalizeUsername(command.username());
        List<AccountRow> accounts = jdbcTemplate.query("""
                SELECT a.id, a.username, a.recovery_code_hash,
                       r.id AS resident_id, r.display_name, r.background_key, r.appearance_seed
                FROM account a JOIN resident r ON r.account_id = a.id
                WHERE a.username = ? AND a.status = 'ACTIVE'
                """, (resultSet, row) -> new AccountRow(
                resultSet.getString("id"), resultSet.getString("username"),
                resultSet.getString("recovery_code_hash"), resultSet.getString("resident_id"),
                resultSet.getString("display_name"), resultSet.getString("background_key"),
                resultSet.getInt("appearance_seed")), username);
        AccountRow account = accounts.stream().findFirst()
                .orElseThrow(() -> new SecurityException("用户名或恢复码错误"));
        if (!hashingService.passwordMatches(command.recoveryCode(), account.recoveryHash())) {
            throw new SecurityException("用户名或恢复码错误");
        }
        return createSession(account);
    }

    @Transactional
    public AuthResult refresh(String refreshToken) {
        if (refreshToken == null || refreshToken.isBlank()) {
            throw new SecurityException("刷新令牌无效");
        }
        String refreshHash = hashingService.sha256(refreshToken);
        List<AccountRow> accounts = jdbcTemplate.query("""
                SELECT a.id, a.username, a.recovery_code_hash,
                       r.id AS resident_id, r.display_name, r.background_key, r.appearance_seed
                FROM access_session s
                JOIN account a ON a.id = s.account_id
                JOIN resident r ON r.account_id = a.id
                WHERE s.refresh_token_hash = ?
                  AND s.revoked_at IS NULL
                  AND s.refresh_expires_at > ?
                  AND a.status = 'ACTIVE'
                """, (resultSet, row) -> new AccountRow(
                resultSet.getString("id"), resultSet.getString("username"),
                resultSet.getString("recovery_code_hash"), resultSet.getString("resident_id"),
                resultSet.getString("display_name"), resultSet.getString("background_key"),
                resultSet.getInt("appearance_seed")), refreshHash, Instant.now().toString());
        AccountRow account = accounts.stream().findFirst()
                .orElseThrow(() -> new SecurityException("刷新令牌无效或已过期"));
        jdbcTemplate.update(
                "UPDATE access_session SET revoked_at = ? WHERE refresh_token_hash = ? AND revoked_at IS NULL",
                Instant.now().toString(), refreshHash);
        return createSession(account);
    }

    private AuthResult createSession(AccountRow account) {
        Instant now = Instant.now();
        String accessToken = hashingService.randomToken(32);
        String refreshToken = hashingService.randomToken(48);
        jdbcTemplate.update("""
                INSERT INTO access_session(
                    id, account_id, access_token_hash, refresh_token_hash,
                    access_expires_at, refresh_expires_at, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """, UUID.randomUUID().toString(), account.accountId(),
                hashingService.sha256(accessToken), hashingService.sha256(refreshToken),
                now.plus(15, ChronoUnit.MINUTES).toString(), now.plus(30, ChronoUnit.DAYS).toString(), now.toString());
        return new AuthResult(account.accountId(), account.residentId(), account.username(),
                account.displayName(), account.background(), account.appearanceSeed(), null,
                accessToken, refreshToken, 900, 2_592_000);
    }

    private String normalizeUsername(String value) {
        String username = value == null ? "" : value.trim().toLowerCase(Locale.ROOT);
        if (!username.matches("[a-z0-9_]{3,20}")) {
            throw new IllegalArgumentException("用户名只能包含 3–20 位小写字母、数字或下划线");
        }
        return username;
    }

    private int randomAxis(int seed, int salt) {
        return 20 + Math.floorMod(seed * salt, 61);
    }

    public record RegisterCommand(String inviteCode, String username, String displayName, boolean privacyAccepted) {}

    public record RecoverCommand(String username, String recoveryCode) {}

    public record AuthResult(
            String accountId,
            String residentId,
            String username,
            String displayName,
            String backgroundKey,
            int appearanceSeed,
            String recoveryCode,
            String accessToken,
            String refreshToken,
            long accessExpiresInSeconds,
            long refreshExpiresInSeconds) {}

    private record AccountRow(
            String accountId,
            String username,
            String recoveryHash,
            String residentId,
            String displayName,
            String background,
            int appearanceSeed) {}
}
