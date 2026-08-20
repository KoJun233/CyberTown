package com.cybertown.server.resident;

import com.cybertown.server.security.AuthenticatedAccount;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/me")
public class ResidentController {

    private final ResidentService residentService;

    public ResidentController(ResidentService residentService) {
        this.residentService = residentService;
    }

    @GetMapping("/resident")
    ResidentView resident(@AuthenticationPrincipal AuthenticatedAccount account) {
        return residentService.getForAccount(account.accountId());
    }
}
