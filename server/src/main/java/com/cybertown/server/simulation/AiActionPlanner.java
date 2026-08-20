package com.cybertown.server.simulation;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.Instant;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.ZoneId;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.chat.metadata.Usage;
import org.springframework.ai.chat.model.ChatModel;
import org.springframework.ai.chat.model.ChatResponse;
import org.springframework.ai.openai.OpenAiChatOptions;
import org.springframework.ai.openai.api.ResponseFormat;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

@Service
public class AiActionPlanner {

    private static final Logger logger = LoggerFactory.getLogger(AiActionPlanner.class);
    private static final Set<String> ALLOWED_ACTIONS = Set.of("REST", "WORK", "TALK", "EXPLORE", "HELP");
    private static final String SYSTEM_PROMPT = """
            你是 CyberTown 的居民行动规划器。你只能从 REST、WORK、TALK、EXPLORE、HELP 中选择一个行动。
            遵守玩家目标，但能量不高时优先 REST。不要生成奖励、数值、地点、人物或世界事实。
            只返回 JSON，例如 {"action":"TALK"}，不要返回 Markdown 或额外字段。
            """;

    private final JdbcTemplate jdbcTemplate;
    private final ObjectMapper objectMapper;
    private final ChatClient chatClient;
    private final ZoneId townZone;
    private final boolean enabled;
    private final String model;
    private final int maxCallsPerResidentDay;
    private final double monthlyBudgetCny;
    private final double inputCostCnyPerMillion;
    private final double outputCostCnyPerMillion;

    public AiActionPlanner(
            JdbcTemplate jdbcTemplate,
            ObjectMapper objectMapper,
            ChatModel chatModel,
            @Value("${cybertown.town-zone:Asia/Shanghai}") String townZone,
            @Value("${cybertown.ai.enabled:false}") boolean enabled,
            @Value("${cybertown.ai.model:deepseek-v4-flash}") String model,
            @Value("${cybertown.ai.max-calls-per-resident-day:4}") int maxCallsPerResidentDay,
            @Value("${cybertown.ai.monthly-budget-cny:200}") double monthlyBudgetCny,
            @Value("${cybertown.ai.input-cost-cny-per-million:1.0}") double inputCostCnyPerMillion,
            @Value("${cybertown.ai.output-cost-cny-per-million:2.0}") double outputCostCnyPerMillion) {
        this.jdbcTemplate = jdbcTemplate;
        this.objectMapper = objectMapper;
        this.chatClient = ChatClient.create(chatModel);
        this.townZone = ZoneId.of(townZone);
        this.enabled = enabled;
        this.model = model;
        this.maxCallsPerResidentDay = maxCallsPerResidentDay;
        this.monthlyBudgetCny = monthlyBudgetCny;
        this.inputCostCnyPerMillion = inputCostCnyPerMillion;
        this.outputCostCnyPerMillion = outputCostCnyPerMillion;
    }

    public Optional<String> chooseAction(PlanningRequest request) {
        if (!enabled || request.goal() == null || request.goal().isBlank()) {
            return Optional.empty();
        }
        if (dailyCalls(request.residentId()) >= maxCallsPerResidentDay || monthlySpend() >= monthlyBudgetCny) {
            return Optional.empty();
        }

        int promptTokens = 0;
        int completionTokens = 0;
        try {
            String userPrompt = """
                    时段：%s
                    玩家目标：%s
                    居民状态：能量 %d，心情 %d，金币 %d
                    性格：社交 %d，好奇 %d，秩序 %d
                    """.formatted(request.slot(), request.goal(), request.energy(), request.mood(), request.coins(),
                    request.personalitySocial(), request.personalityCuriosity(), request.personalityOrder());
            OpenAiChatOptions options = OpenAiChatOptions.builder()
                    .model(model)
                    .temperature(0.2)
                    .maxTokens(80)
                    .responseFormat(ResponseFormat.builder().type(ResponseFormat.Type.JSON_OBJECT).build())
                    .extraBody(Map.of("thinking", Map.of("type", "disabled")))
                    .build();
            ChatResponse response = chatClient.prompt()
                    .system(SYSTEM_PROMPT)
                    .user(userPrompt)
                    .options(options)
                    .call()
                    .chatResponse();
            if (response == null || response.getResult() == null) {
                throw new IllegalStateException("DeepSeek 返回空响应");
            }
            Usage usage = response.getMetadata().getUsage();
            promptTokens = valueOrZero(usage.getPromptTokens());
            completionTokens = valueOrZero(usage.getCompletionTokens());
            AiDecision decision = objectMapper.readValue(response.getResult().getOutput().getText(), AiDecision.class);
            String action = decision.action() == null ? "" : decision.action().trim().toUpperCase();
            if (!ALLOWED_ACTIONS.contains(action)) {
                throw new IllegalArgumentException("DeepSeek 返回了不允许的行动");
            }
            recordUsage(request.residentId(), promptTokens, completionTokens, "SUCCESS");
            return Optional.of(action);
        } catch (Exception exception) {
            recordUsage(request.residentId(), promptTokens, completionTokens, "FAILED");
            logger.warn("AI 行动规划失败，居民 {} 将使用规则引擎：{}", request.residentId(), exception.getMessage());
            return Optional.empty();
        }
    }

    private int dailyCalls(String residentId) {
        LocalDate today = LocalDate.now(townZone);
        Instant start = today.atStartOfDay(townZone).toInstant();
        Instant end = today.plusDays(1).atStartOfDay(townZone).toInstant();
        Integer count = jdbcTemplate.queryForObject("""
                SELECT COUNT(*) FROM ai_usage
                WHERE resident_id = ? AND created_at >= ? AND created_at < ?
                """, Integer.class, residentId, start.toString(), end.toString());
        return count == null ? 0 : count;
    }

    private double monthlySpend() {
        Instant start = YearMonth.now(townZone).atDay(1).atStartOfDay(townZone).toInstant();
        Double spend = jdbcTemplate.queryForObject("""
                SELECT COALESCE(SUM(estimated_cost_cny), 0) FROM ai_usage WHERE created_at >= ?
                """, Double.class, start.toString());
        return spend == null ? 0 : spend;
    }

    private void recordUsage(String residentId, int promptTokens, int completionTokens, String outcome) {
        double estimatedCost = (promptTokens * inputCostCnyPerMillion
                + completionTokens * outputCostCnyPerMillion) / 1_000_000d;
        jdbcTemplate.update("""
                INSERT INTO ai_usage(
                    id, resident_id, purpose, model, prompt_tokens, cached_prompt_tokens,
                    completion_tokens, estimated_cost_cny, outcome, created_at)
                VALUES (?, ?, 'ACTION_PLANNING', ?, ?, 0, ?, ?, ?, ?)
                """, UUID.randomUUID().toString(), residentId, model, promptTokens, completionTokens,
                estimatedCost, outcome, Instant.now().toString());
    }

    private int valueOrZero(Integer value) {
        return value == null ? 0 : value;
    }

    public record PlanningRequest(
            String residentId,
            TimeSlot slot,
            String goal,
            int energy,
            int mood,
            int coins,
            int personalitySocial,
            int personalityCuriosity,
            int personalityOrder) {}

    private record AiDecision(String action) {}
}
