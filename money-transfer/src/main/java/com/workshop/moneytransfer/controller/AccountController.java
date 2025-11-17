package com.workshop.moneytransfer.controller;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.*;

@RestController
@RequestMapping("/api/accounts")
public class AccountController {

    private static final Logger logger = LoggerFactory.getLogger(AccountController.class);
    private final Map<String, Account> accounts = new HashMap<>();

    @GetMapping
    public ResponseEntity<List<Account>> getAllAccounts() {
        MDC.put("operation", "getAllAccounts");
        logger.info("Fetching all accounts");

        List<Account> accountList = new ArrayList<>(accounts.values());
        logger.debug("Found {} accounts", accountList.size());

        MDC.clear();
        return ResponseEntity.ok(accountList);
    }

    @GetMapping("/{accountNumber}")
    public ResponseEntity<Account> getAccount(@PathVariable String accountNumber) {
        MDC.put("operation", "getAccount");
        MDC.put("accountNumber", accountNumber);

        logger.info("Fetching account: {}", accountNumber);

        Account account = accounts.get(accountNumber);
        if (account == null) {
            logger.warn("Account not found: {}", accountNumber);
            MDC.clear();
            return ResponseEntity.notFound().build();
        }

        logger.debug("Account found: {}", account);
        MDC.clear();
        return ResponseEntity.ok(account);
    }

    @PostMapping
    public ResponseEntity<Account> createAccount(@RequestBody Account account) {
        MDC.put("operation", "createAccount");
        MDC.put("accountNumber", account.getAccountNumber());

        logger.info("Creating new account: {}", account.getAccountNumber());

        if (accounts.containsKey(account.getAccountNumber())) {
            logger.error("Account already exists: {}", account.getAccountNumber());
            MDC.clear();
            return ResponseEntity.badRequest().build();
        }

        accounts.put(account.getAccountNumber(), account);
        logger.info("Account created successfully: {}", account.getAccountNumber());

        MDC.clear();
        return ResponseEntity.ok(account);
    }

    @DeleteMapping("/{accountNumber}")
    public ResponseEntity<Void> deleteAccount(@PathVariable String accountNumber) {
        MDC.put("operation", "deleteAccount");
        MDC.put("accountNumber", accountNumber);

        logger.info("Deleting account: {}", accountNumber);

        Account removed = accounts.remove(accountNumber);
        if (removed == null) {
            logger.warn("Cannot delete - account not found: {}", accountNumber);
            MDC.clear();
            return ResponseEntity.notFound().build();
        }

        logger.info("Account deleted successfully: {}", accountNumber);
        MDC.clear();
        return ResponseEntity.noContent().build();
    }

    // Inner class
    public static class Account {
        private String accountNumber;
        private String accountHolderName;
        private Double balance;

        // Getters and setters
        public String getAccountNumber() {
            return accountNumber;
        }

        public void setAccountNumber(String accountNumber) {
            this.accountNumber = accountNumber;
        }

        public String getAccountHolderName() {
            return accountHolderName;
        }

        public void setAccountHolderName(String accountHolderName) {
            this.accountHolderName = accountHolderName;
        }

        public Double getBalance() {
            return balance;
        }

        public void setBalance(Double balance) {
            this.balance = balance;
        }

        @Override
        public String toString() {
            return "Account{accountNumber='" + accountNumber + "', balance=" + balance + "}";
        }
    }
}