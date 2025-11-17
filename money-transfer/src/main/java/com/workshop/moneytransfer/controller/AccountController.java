package com.workshop.moneytransfer.controller;

import com.workshop.moneytransfer.dto.CreateAccountRequest;
import com.workshop.moneytransfer.exception.AccountNotFoundException;
import com.workshop.moneytransfer.model.Account;
import com.workshop.moneytransfer.service.AccountService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/accounts")
public class AccountController {

    private static final Logger logger = LoggerFactory.getLogger(AccountController.class);
    private final AccountService accountService;

    public AccountController(AccountService accountService) {
        this.accountService = accountService;
    }

    @GetMapping
    public ResponseEntity<List<Account>> getAllAccounts() {
        MDC.put("operation", "getAllAccounts");
        logger.info("Fetching all accounts");

        List<Account> accounts = accountService.getAllAccounts();
        logger.debug("Found {} accounts", accounts.size());

        MDC.clear();
        return ResponseEntity.ok(accounts);
    }

    @GetMapping("/{accountNumber}")
    public ResponseEntity<?> getAccount(@PathVariable String accountNumber) {
        MDC.put("operation", "getAccount");
        MDC.put("accountNumber", accountNumber);

        logger.info("Fetching account: {}", accountNumber);

        try {
            Account account = accountService.getAccount(accountNumber);
            logger.debug("Account found: {}", account.getAccountNumber());
            MDC.clear();
            return ResponseEntity.ok(account);
        } catch (AccountNotFoundException e) {
            logger.warn("Account not found: {}", accountNumber);
            MDC.clear();
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(Map.of("error", e.getMessage()));
        }
    }

    @PostMapping
    public ResponseEntity<?> createAccount(@RequestBody CreateAccountRequest request) {
        MDC.put("operation", "createAccount");
        MDC.put("accountHolder", request.getAccountHolderName());

        logger.info("Creating new account for: {}", request.getAccountHolderName());

        try {
            Account account = accountService.createAccount(
                    request.getAccountHolderName(),
                    request.getInitialBalance());
            logger.info("Account created successfully: {}", account.getAccountNumber());
            MDC.clear();
            return ResponseEntity.status(HttpStatus.CREATED).body(account);
        } catch (Exception e) {
            logger.error("Failed to create account: {}", e.getMessage());
            MDC.clear();
            return ResponseEntity.badRequest()
                    .body(Map.of("error", e.getMessage()));
        }
    }

    @GetMapping("/{accountNumber}/balance")
    public ResponseEntity<?> getBalance(@PathVariable String accountNumber) {
        MDC.put("operation", "getBalance");
        MDC.put("accountNumber", accountNumber);

        logger.info("Fetching balance for account: {}", accountNumber);

        try {
            Account account = accountService.getAccount(accountNumber);
            logger.debug("Balance for {}: {}", accountNumber, account.getBalance());
            MDC.clear();
            return ResponseEntity.ok(Map.of(
                    "accountNumber", account.getAccountNumber(),
                    "accountHolderName", account.getAccountHolderName(),
                    "balance", account.getBalance(),
                    "currency", account.getCurrency(),
                    "status", account.getStatus()));
        } catch (AccountNotFoundException e) {
            logger.warn("Account not found: {}", accountNumber);
            MDC.clear();
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(Map.of("error", e.getMessage()));
        }
    }

    @PatchMapping("/{accountNumber}/status")
    public ResponseEntity<?> updateAccountStatus(
            @PathVariable String accountNumber,
            @RequestBody Map<String, String> request) {
        MDC.put("operation", "updateAccountStatus");
        MDC.put("accountNumber", accountNumber);

        String newStatus = request.get("status");
        logger.info("Updating account {} status to: {}", accountNumber, newStatus);

        try {
            Account account = accountService.updateAccountStatus(accountNumber, newStatus);
            logger.info("Account status updated successfully: {}", accountNumber);
            MDC.clear();
            return ResponseEntity.ok(account);
        } catch (AccountNotFoundException e) {
            logger.warn("Account not found: {}", accountNumber);
            MDC.clear();
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(Map.of("error", e.getMessage()));
        }
    }
}