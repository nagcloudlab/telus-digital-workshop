package com.workshop.moneytransfer.controller;

import com.workshop.moneytransfer.dto.TransferRequest;
import com.workshop.moneytransfer.model.Transaction;
import com.workshop.moneytransfer.service.TransferService;

import io.micrometer.observation.annotation.Observed;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/transfers")
@RequiredArgsConstructor
public class TransferController {

    private final TransferService transferService;

    @PostMapping
    @Observed(name = "money.transfer", contextualName = "Money Transfer")
    public ResponseEntity<Transaction> transfer(@Valid @RequestBody TransferRequest request) {
        Transaction transaction = transferService.transfer(
                request.getFromAccountNumber(),
                request.getToAccountNumber(),
                request.getAmount(),
                request.getDescription());

        return ResponseEntity.status(HttpStatus.CREATED).body(transaction);
    }

    @GetMapping("/history/{accountNumber}")
    @Observed(name = "transaction.history", contextualName = "Transaction History")
    public ResponseEntity<List<Transaction>> getTransactionHistory(
            @PathVariable String accountNumber) {

        List<Transaction> transactions = transferService.getTransactionHistory(accountNumber);
        return ResponseEntity.ok(transactions);
    }
}