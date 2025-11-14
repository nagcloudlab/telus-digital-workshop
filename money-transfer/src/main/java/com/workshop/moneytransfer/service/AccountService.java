package com.workshop.moneytransfer.service;

import com.workshop.moneytransfer.exception.AccountNotFoundException;
import com.workshop.moneytransfer.model.Account;
import com.workshop.moneytransfer.repository.AccountRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;
import java.util.Random;

@Service
@RequiredArgsConstructor
@Slf4j
public class AccountService {

    private final AccountRepository accountRepository;
    private final Random random = new Random();

    @Transactional
    public Account createAccount(String accountHolderName, BigDecimal initialBalance) {

        String accountNumber = generateAccountNumber();

        Account account = new Account();
        account.setAccountNumber(accountNumber);
        account.setAccountHolderName(accountHolderName);
        account.setBalance(initialBalance);
        account.setCurrency("USD");
        account.setStatus("ACTIVE");

        Account savedAccount = accountRepository.save(account);
        log.info("Created new account: {} for {}", accountNumber, accountHolderName);

        return savedAccount;
    }

    public Account getAccount(String accountNumber) {
        return accountRepository.findByAccountNumber(accountNumber)
                .orElseThrow(() -> new AccountNotFoundException(
                        "Account not found: " + accountNumber));
    }

    public List<Account> getAllAccounts() {
        return accountRepository.findAll();
    }

    public BigDecimal getBalance(String accountNumber) {
        Account account = getAccount(accountNumber);
        return account.getBalance();
    }

    @Transactional
    public Account updateAccountStatus(String accountNumber, String status) {
        Account account = getAccount(accountNumber);
        account.setStatus(status);
        return accountRepository.save(account);
    }

    private String generateAccountNumber() {
        // Generate 10-digit account number
        StringBuilder accountNumber = new StringBuilder();
        for (int i = 0; i < 10; i++) {
            accountNumber.append(random.nextInt(10));
        }

        // Ensure uniqueness
        String number = accountNumber.toString();
        if (accountRepository.existsByAccountNumber(number)) {
            return generateAccountNumber(); // Recursive call if duplicate
        }

        return number;
    }
}