package com.cybertown.server.town;

import com.cybertown.server.security.AuthenticatedAccount;
import com.cybertown.server.town.TownSnapshot.TownBubble;
import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/town")
public class TownController {

    private final TownService townService;

    public TownController(TownService townService) {
        this.townService = townService;
    }

    @GetMapping("/snapshot")
    TownSnapshot snapshot(@AuthenticationPrincipal AuthenticatedAccount account) {
        return townService.snapshot(account.accountId());
    }

    @PostMapping("/presence")
    Map<String, Object> updatePresence(
            @AuthenticationPrincipal AuthenticatedAccount account,
            @Valid @RequestBody PresenceRequest request) {
        townService.updatePresence(account.accountId(), request.x(), request.y());
        return Map.of("updated", true);
    }

    @PostMapping("/bubbles")
    @ResponseStatus(HttpStatus.CREATED)
    TownBubble sendBubble(
            @AuthenticationPrincipal AuthenticatedAccount account,
            @Valid @RequestBody BubbleRequest request) {
        return townService.sendBubble(account.accountId(), request.message());
    }

    record PresenceRequest(
            @NotNull @DecimalMin("0") @DecimalMax("640") Double x,
            @NotNull @DecimalMin("0") @DecimalMax("360") Double y) {}

    record BubbleRequest(
            @NotBlank(message = "气泡内容不能为空")
            @Size(max = 120, message = "气泡内容最多 60 个字符")
            String message) {}
}
