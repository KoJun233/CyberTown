package com.cybertown.server.auth;

import jakarta.validation.Valid;
import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    @PostMapping("/register")
    @ResponseStatus(HttpStatus.CREATED)
    AuthService.AuthResult register(@Valid @RequestBody RegisterRequest request) {
        return authService.register(new AuthService.RegisterCommand(
                request.inviteCode(), request.username(), request.displayName(), request.privacyAccepted()));
    }

    @PostMapping("/recover")
    AuthService.AuthResult recover(@Valid @RequestBody RecoverRequest request) {
        return authService.recover(new AuthService.RecoverCommand(request.username(), request.recoveryCode()));
    }

    @PostMapping("/refresh")
    AuthService.AuthResult refresh(@Valid @RequestBody RefreshRequest request) {
        return authService.refresh(request.refreshToken());
    }

    public record RegisterRequest(
            @NotBlank(message = "请输入邀请码") String inviteCode,
            @NotBlank(message = "请输入用户名") String username,
            @Size(max = 20, message = "居民名称不能超过 20 个字符") String displayName,
            @AssertTrue(message = "必须同意测试与隐私说明") boolean privacyAccepted) {}

    public record RecoverRequest(
            @NotBlank(message = "请输入用户名") String username,
            @NotBlank(message = "请输入恢复码") String recoveryCode) {}

    public record RefreshRequest(@NotBlank(message = "请输入刷新令牌") String refreshToken) {}
}
