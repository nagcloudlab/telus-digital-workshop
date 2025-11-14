package com.workshop.moneytransfer.service;

import com.workshop.moneytransfer.exception.AccountNotFoundException;
import com.workshop.moneytransfer.exception.InsufficientFundsException;
import com.workshop.moneytransfer.model.Account;
import com.workshop.moneytransfer.model.Transaction;
import com.workshop.moneytransfer.repository.AccountRepository;
import com.workshop.moneytransfer.repository.TransactionRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class TransferService {

    private final AccountRepository accountRepository;
    private final TransactionRepository transactionRepository;

    /**
     * Transfer money between accounts
     * Implements the sequence diagram logic:
     * 1. Load both accounts
     * 2. Validate sufficient funds
     * 3. Debit from source account
     * 4. Credit to destination account
     * 5. Update both accounts
     * 6. Record transaction
     */
    @Transactional
    public Transaction transfer(String fromAccountNumber, String toAccountNumber,
            BigDecimal amount, String description) {

        log.info("Starting transfer: {} -> {}, amount: {}",
                fromAccountNumber, toAccountNumber, amount);

        // Step 1: Load Account 1 (from account)
        Account fromAccount = accountRepository.findByAccountNumber(fromAccountNumber)
                .orElseThrow(() -> new AccountNotFoundException(
                        "Source account not found: " + fromAccountNumber));

        // Step 2: Load Account 2 (to account)
        Account toAccount = accountRepository.findByAccountNumber(toAccountNumber)
                .orElseThrow(() -> new AccountNotFoundException(
                        "Destination account not found: " + toAccountNumber));

        // Validate accounts are active
        if (!"ACTIVE".equals(fromAccount.getStatus())) {
            throw new IllegalStateException("Source account is not active");
        }

        if (!"ACTIVE".equals(toAccount.getStatus())) {
            throw new IllegalStateException("Destination account is not active");
        }

        // Validate amount
        if (amount.compareTo(BigDecimal.ZERO) <= 0) {
            throw new IllegalArgumentException("Transfer amount must be positive");
        }

        // Check sufficient funds
        if (fromAccount.getBalance().compareTo(amount) < 0) {
            String errorMsg = String.format(
                    "Insufficient funds in account %s. Balance: %s, Required: %s",
                    fromAccountNumber, fromAccount.getBalance(), amount);

            // Record failed transaction
            Transaction failedTransaction = createTransaction(
                    fromAccountNumber, toAccountNumber, amount,
                    description, "FAILED", errorMsg);
            transactionRepository.save(failedTransaction);

            throw new InsufficientFundsException(errorMsg);
        }

        // Step 3: Debit from source account
        fromAccount.debit(amount);
        log.info("Debited {} from account {}", amount, fromAccountNumber);

        // Step 4: Credit to destination account
        toAccount.credit(amount);
        log.info("Credited {} to account {}", amount, toAccountNumber);

        // Step 5: Update both accounts
        accountRepository.save(fromAccount);
        accountRepository.save(toAccount);

        // Step 6: Record successful transaction
        Transaction transaction = createTransaction(
                fromAccountNumber, toAccountNumber, amount,
                description, "SUCCESS", null);

        Transaction savedTransaction = transactionRepository.save(transaction);

        log.info("Transfer completed successfully. Transaction ID: {}",
                savedTransaction.getTransactionId());

        return savedTransaction;
    }

    public List<Transaction> getTransactionHistory(String accountNumber) {
        return transactionRepository.findByFromAccountNumberOrToAccountNumber(
                accountNumber, accountNumber);
    }

    private Transaction createTransaction(String fromAccountNumber,
            String toAccountNumber,
            BigDecimal amount,
            String description,
            String status,
            String failureReason) {
        Transaction transaction = new Transaction();
        transaction.setTransactionId(UUID.randomUUID().toString());
        transaction.setFromAccountNumber(fromAccountNumber);
        transaction.setToAccountNumber(toAccountNumber);
        transaction.setAmount(amount);
        transaction.setCurrency("USD");
        transaction.setDescription(description);
        transaction.setStatus(status);
        transaction.setFailureReason(failureReason);

        return transaction;
    }
}