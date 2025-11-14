package com.workshop.moneytransfer.controller;

import com.workshop.moneytransfer.dto.CreateAccountRequest;
import com.workshop.moneytransfer.model.Account;
import com.workshop.moneytransfer.service.AccountService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/accounts")
@RequiredArgsConstructor
public class AccountController {

    private final AccountService accountService;

    @PostMapping
    public ResponseEntity<Account> createAccount(
            @Valid @RequestBody CreateAccountRequest request) {

        Account account = accountService.createAccount(
                request.getAccountHolderName(),
                request.getInitialBalance());

        return ResponseEntity.status(HttpStatus.CREATED).body(account);
    }

    @GetMapping("/{accountNumber}")
    public ResponseEntity<Account> getAccount(@PathVariable String accountNumber) {
        Account account = accountService.getAccount(accountNumber);
        return ResponseEntity.ok(account);
    }

    @GetMapping
    public ResponseEntity<List<Account>> getAllAccounts() {
        List<Account> accounts = accountService.getAllAccounts();
        return ResponseEntity.ok(accounts);
    }

    @GetMapping("/{accountNumber}/balance")
    public ResponseEntity<Map<String, BigDecimal>> getBalance(
            @PathVariable String accountNumber) {

        BigDecimal balance = accountService.getBalance(accountNumber);
        return ResponseEntity.ok(Map.of("balance", balance));
    }

    @PutMapping("/{accountNumber}/status")
    public ResponseEntity<Account> updateStatus(
            @PathVariable String accountNumber,
            @RequestParam String status) {

        Account account = accountService.updateAccountStatus(accountNumber, status);
        return ResponseEntity.ok(account);
    }
}