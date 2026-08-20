package com.cybertown.server.security;

import java.security.Principal;

public record AuthenticatedAccount(String accountId, String username) implements Principal {
    @Override
    public String getName() {
        return accountId;
    }
}
