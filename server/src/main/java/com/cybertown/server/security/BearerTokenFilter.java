package com.cybertown.server.security;

import com.cybertown.server.common.HashingService;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.time.Instant;
import java.util.List;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

@Component
public class BearerTokenFilter extends OncePerRequestFilter {

    private final JdbcTemplate jdbcTemplate;
    private final HashingService hashingService;

    public BearerTokenFilter(JdbcTemplate jdbcTemplate, HashingService hashingService) {
        this.jdbcTemplate = jdbcTemplate;
        this.hashingService = hashingService;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        String authorization = request.getHeader("Authorization");
        if (authorization != null && authorization.startsWith("Bearer ")) {
            String tokenHash = hashingService.sha256(authorization.substring(7));
            List<AuthenticatedAccount> accounts = jdbcTemplate.query("""
                    SELECT a.id, a.username
                    FROM access_session s
                    JOIN account a ON a.id = s.account_id
                    WHERE s.access_token_hash = ?
                      AND s.revoked_at IS NULL
                      AND s.access_expires_at > ?
                      AND a.status IN ('ACTIVE', 'MUTED')
                    """, (resultSet, row) -> new AuthenticatedAccount(
                    resultSet.getString("id"), resultSet.getString("username")), tokenHash, Instant.now().toString());
            accounts.stream().findFirst().ifPresent(account -> SecurityContextHolder.getContext().setAuthentication(
                    new UsernamePasswordAuthenticationToken(account, tokenHash, List.of())));
        }
        chain.doFilter(request, response);
    }
}
