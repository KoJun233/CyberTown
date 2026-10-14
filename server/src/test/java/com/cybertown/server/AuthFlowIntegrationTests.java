package com.cybertown.server;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;
import java.util.Map;
import java.util.UUID;
import com.cybertown.server.simulation.SimulationService;
import com.cybertown.server.simulation.TimeSlot;
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
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.context.ActiveProfiles;

@ActiveProfiles("test")
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class AuthFlowIntegrationTests {

    private static final String INVITE_CODE = "CYBER-INTEGRATION-TEST";
    private static final String DATABASE_PATH = "target/cybertown-auth-flow-" + UUID.randomUUID() + ".db";

    @DynamicPropertySource
    static void properties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", () -> "jdbc:sqlite:" + DATABASE_PATH);
        registry.add("cybertown.bootstrap-invite-code", () -> INVITE_CODE);
        registry.add("spring.ai.openai.api-key", () -> "test-key");
        registry.add("spring.ai.openai.base-url", () -> "http://localhost:65535");
    }

    @LocalServerPort
    int port;

    @Autowired
    TestRestTemplate restTemplate;

    @Autowired
    SimulationService simulationService;

    @Test
    void registrationGoalAndReportFlowWorks() {
        ResponseEntity<Map<String, Object>> registration = post("/api/auth/register", Map.of(
                "inviteCode", INVITE_CODE,
                "username", "test_resident",
                "displayName", "测试居民",
                "privacyAccepted", true));

        assertThat(registration.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(registration.getBody()).isNotNull();
        String accessToken = registration.getBody().get("accessToken").toString();
        String refreshToken = registration.getBody().get("refreshToken").toString();
        assertThat(registration.getBody().get("recoveryCode")).isNotNull();

        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(accessToken);
        ResponseEntity<Map<String, Object>> resident = exchange(
                "/api/me/resident", HttpMethod.GET, new HttpEntity<>(headers));
        assertThat(resident.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(resident.getBody()).containsEntry("displayName", "测试居民");

        ResponseEntity<Map<String, Object>> goal = exchange(
                "/api/goals", HttpMethod.POST,
                new HttpEntity<>(Map.of(
                        "instruction", "今天努力赚钱",
                        "constraints", List.of("不要透支精力")), headers));
        assertThat(goal.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(goal.getBody()).containsEntry("instruction", "今天努力赚钱");

        assertThat(simulationService.runSlot(TimeSlot.AFTERNOON)).isEqualTo(1);

        ResponseEntity<Map<String, Object>> report = exchange(
                "/api/reports/today", HttpMethod.GET, new HttpEntity<>(headers));
        assertThat(report.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(report.getBody()).containsEntry("goal", "今天努力赚钱");
        assertThat(report.getBody()).containsEntry("constraints", List.of("不要透支精力"));
        assertThat((List<?>) report.getBody().get("actions")).hasSize(1);

        ResponseEntity<Map<String, Object>> refreshed = post(
                "/api/auth/refresh", Map.of("refreshToken", refreshToken));
        assertThat(refreshed.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(refreshed.getBody()).containsKey("accessToken");
    }

    private ResponseEntity<Map<String, Object>> post(String path, Object body) {
        return exchange(path, HttpMethod.POST, new HttpEntity<>(body));
    }

    private ResponseEntity<Map<String, Object>> exchange(String path, HttpMethod method, HttpEntity<?> entity) {
        return restTemplate.exchange(
                "http://localhost:" + port + path,
                method,
                entity,
                new ParameterizedTypeReference<>() {});
    }
}
