package com.cybertown.server;

import static org.assertj.core.api.Assertions.assertThat;

import com.cybertown.server.common.HashingService;
import com.cybertown.server.simulation.SimulationService;
import com.cybertown.server.simulation.TimeSlot;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.context.ActiveProfiles;

@ActiveProfiles("test")
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class TownIntegrationTests {

    private static final String DATABASE_PATH = "target/cybertown-town-" + UUID.randomUUID() + ".db";

    @DynamicPropertySource
    static void properties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", () -> "jdbc:sqlite:" + DATABASE_PATH);
        registry.add("cybertown.bootstrap-invite-code", () -> "");
        registry.add("cybertown.ai.enabled", () -> "false");
    }

    @Autowired TestRestTemplate http;
    @Autowired JdbcTemplate jdbc;
    @Autowired HashingService hashing;
    @Autowired SimulationService simulation;
    @LocalServerPort int port;

    private Player first;
    private Player second;

    @BeforeEach
    void players() {
        for (String table : List.of("town_bubble", "resident_presence", "access_session", "daily_goal",
                "resident_action", "event_log", "ai_usage", "resident", "invite_code", "account")) {
            jdbc.execute("DELETE FROM " + table);
        }
        first = register("neighbor_one");
        second = register("neighbor_two");
        move(first, 100, 150);
        move(second, 130, 160);
    }

    @Test
    void snapshotShowsSharedResidentsWithoutExposingAccountSecrets() {
        var response = get(first, "/api/town/snapshot");
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(residents(response)).hasSize(2);
        assertThat(residents(response).stream().filter(r -> Boolean.TRUE.equals(r.get("current"))).count()).isEqualTo(1);
        assertThat(response.getBody()).containsKeys("townDate", "townTime", "timeOfDay", "resident");
        assertThat(residents(response).toString()).doesNotContain("accessToken", "accountId", "recoveryCode");
        var own = residents(get(second, "/api/town/snapshot")).stream()
                .filter(r -> second.residentId().equals(r.get("id"))).findFirst().orElseThrow();
        assertThat(((Number) own.get("posX")).doubleValue()).isEqualTo(130);
    }

    @Test
    void nearbyBubblesAreFilteredByDistanceAndExpire() {
        var sent = post(first, "/api/town/bubbles", Map.of("message", "你好，邻居"));
        assertThat(sent.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(bubbles(get(second, "/api/town/snapshot"))).hasSize(1);
        move(second, 620, 320);
        assertThat(bubbles(get(second, "/api/town/snapshot"))).isEmpty();
        move(second, 130, 160);
        jdbc.update("UPDATE town_bubble SET expires_at = ? WHERE id = ?",
                Instant.now().minusSeconds(1).toString(), sent.getBody().get("id"));
        assertThat(bubbles(get(second, "/api/town/snapshot"))).isEmpty();
    }

    @Test
    void cooldownIsPersistedAndAllowsSendingAgainAfterTenSeconds() {
        var sent = post(first, "/api/town/bubbles", Map.of("message", "第一句话"));
        assertThat(sent.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        var throttled = post(first, "/api/town/bubbles", Map.of("message", "连续发送"));
        assertThat(throttled.getStatusCode()).isEqualTo(HttpStatus.TOO_MANY_REQUESTS);
        assertThat(throttled.getBody().get("message").toString()).contains("等待");
        jdbc.update("UPDATE town_bubble SET created_at = ? WHERE resident_id = ?",
                Instant.now().minusSeconds(11).toString(), first.residentId());
        assertThat(post(first, "/api/town/bubbles", Map.of("message", "现在可以发送"))
                .getStatusCode()).isEqualTo(HttpStatus.CREATED);
    }

    @Test
    void concurrentSendsCannotBypassCooldown() throws Exception {
        try (var executor = Executors.newVirtualThreadPerTaskExecutor()) {
            var one = executor.submit(() -> post(first, "/api/town/bubbles", Map.of("message", "并发一")));
            var two = executor.submit(() -> post(first, "/api/town/bubbles", Map.of("message", "并发二")));
            assertThat(List.of(one.get(10, TimeUnit.SECONDS).getStatusCode(),
                    two.get(10, TimeUnit.SECONDS).getStatusCode()))
                    .containsExactlyInAnyOrder(HttpStatus.CREATED, HttpStatus.TOO_MANY_REQUESTS);
        }
    }

    @Test
    void mutedResidentsCanWatchAndMoveButCannotSendBubbles() {
        jdbc.update("UPDATE account SET status = 'MUTED' WHERE id = ?", first.accountId());
        assertThat(get(first, "/api/town/snapshot").getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(post(first, "/api/town/presence", Map.of("x", 120, "y", 150))
                .getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(post(first, "/api/town/bubbles", Map.of("message", "不能发送"))
                .getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
        jdbc.update("UPDATE account SET status = 'BANNED' WHERE id = ?", first.accountId());
        assertThat(get(first, "/api/town/snapshot").getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        assertThat(residents(get(second, "/api/town/snapshot"))).hasSize(1);
    }

    @Test
    void inputValidationRejectsEmptyMessagesAndMalformedCoordinates() {
        assertThat(post(first, "/api/town/bubbles", Map.of("message", "   "))
                .getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(post(first, "/api/town/bubbles", Map.of("message", "字".repeat(61)))
                .getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(post(first, "/api/town/presence", Map.of("x", -1, "y", 150))
                .getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(post(first, "/api/town/presence", Map.of("x", 100))
                .getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(post(first, "/api/town/bubbles", Map.of("message", "🙂".repeat(60)))
                .getStatusCode()).isEqualTo(HttpStatus.CREATED);
    }

    @Test
    void expiredAccessIs401AndRefreshRestoresTownAccess() {
        jdbc.update("UPDATE access_session SET access_expires_at = ? WHERE account_id = ?",
                Instant.now().minusSeconds(1).toString(), first.accountId());
        var expired = get(first, "/api/town/snapshot");
        assertThat(expired.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        assertThat(expired.getBody()).containsKey("message");
        var renewed = post(null, "/api/auth/refresh", Map.of("refreshToken", first.refreshToken()));
        assertThat(renewed.getStatusCode()).isEqualTo(HttpStatus.OK);
        var refreshed = new Player(first.accountId(), first.residentId(),
                renewed.getBody().get("accessToken").toString(), renewed.getBody().get("refreshToken").toString());
        assertThat(get(refreshed, "/api/town/snapshot").getStatusCode()).isEqualTo(HttpStatus.OK);
    }

    @Test
    void offlineActionsUpdateSharedMapPositionsAndRemainIdempotent() {
        assertThat(simulation.runSlot(TimeSlot.AFTERNOON)).isEqualTo(2);
        assertThat(simulation.runSlot(TimeSlot.AFTERNOON)).isZero();
        var response = get(first, "/api/town/snapshot");
        @SuppressWarnings("unchecked")
        var resident = (Map<String, Object>) response.getBody().get("resident");
        assertThat(resident).containsEntry("locationKey", "workshop");
        var own = residents(response).stream().filter(r -> Boolean.TRUE.equals(r.get("current")))
                .findFirst().orElseThrow();
        assertThat(((Number) own.get("posX")).doubleValue()).isBetween(450.0, 474.0);
    }

    private Player register(String username) {
        String invite = UUID.randomUUID().toString();
        jdbc.update("INSERT INTO invite_code(id, code_hash, status, created_at) VALUES (?, ?, 'ACTIVE', ?)",
                UUID.randomUUID().toString(), hashing.sha256(invite), Instant.now().toString());
        var response = post(null, "/api/auth/register", Map.of("inviteCode", invite, "username", username,
                "displayName", username, "privacyAccepted", true));
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        var data = response.getBody();
        return new Player(data.get("accountId").toString(), data.get("residentId").toString(),
                data.get("accessToken").toString(), data.get("refreshToken").toString());
    }

    private void move(Player player, double x, double y) {
        assertThat(post(player, "/api/town/presence", Map.of("x", x, "y", y)).getStatusCode()).isEqualTo(HttpStatus.OK);
    }

    private ResponseEntity<Map<String, Object>> get(Player player, String path) {
        return exchange(player, path, HttpMethod.GET, null);
    }

    private ResponseEntity<Map<String, Object>> post(Player player, String path, Object body) {
        return exchange(player, path, HttpMethod.POST, body);
    }

    private ResponseEntity<Map<String, Object>> exchange(Player player, String path, HttpMethod method, Object body) {
        var headers = new HttpHeaders();
        if (player != null) headers.setBearerAuth(player.token());
        return http.exchange("http://localhost:" + port + path, method, new HttpEntity<>(body, headers),
                new ParameterizedTypeReference<>() {});
    }

    @SuppressWarnings("unchecked")
    private List<Map<String, Object>> residents(ResponseEntity<Map<String, Object>> response) {
        return (List<Map<String, Object>>) response.getBody().get("residents");
    }

    @SuppressWarnings("unchecked")
    private List<Map<String, Object>> bubbles(ResponseEntity<Map<String, Object>> response) {
        return (List<Map<String, Object>>) response.getBody().get("bubbles");
    }

    private record Player(String accountId, String residentId, String token, String refreshToken) {}
}
