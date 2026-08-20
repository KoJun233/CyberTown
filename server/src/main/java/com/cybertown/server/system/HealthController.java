package com.cybertown.server.system;

import java.time.Instant;
import java.util.Map;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api")
public class HealthController {

    @GetMapping("/health")
    Map<String, Object> health() {
        return Map.of("status", "UP", "time", Instant.now().toString());
    }
}
