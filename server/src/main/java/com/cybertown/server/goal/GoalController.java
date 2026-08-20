package com.cybertown.server.goal;

import com.cybertown.server.security.AuthenticatedAccount;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.List;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/goals")
public class GoalController {

    private final GoalService goalService;

    public GoalController(GoalService goalService) {
        this.goalService = goalService;
    }

    @PostMapping
    GoalService.GoalView setGoal(
            @AuthenticationPrincipal AuthenticatedAccount account,
            @Valid @RequestBody GoalRequest request) {
        return goalService.setGoal(account.accountId(), request.instruction(), request.constraints());
    }

    public record GoalRequest(
            @NotBlank(message = "请输入今日目标") @Size(max = 500) String instruction,
            @Size(max = 2, message = "最多设置两条限制") List<String> constraints) {}
}
