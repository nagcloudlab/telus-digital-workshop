package com.workshop.moneytransfer.service;

import com.workshop.moneytransfer.exception.AccountNotFoundException;
import com.workshop.moneytransfer.exception.InsufficientFundsException;
import com.workshop.moneytransfer.model.Account;
import com.workshop.moneytransfer.model.Transaction;
import com.workshop.moneytransfer.repository.AccountRepository;
import com.workshop.moneytransfer.repository.TransactionRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.*;

@Tag("unit")
@ExtendWith(MockitoExtension.class)
class TransferServiceTest {

        @Mock
        private AccountRepository accountRepository;

        @Mock
        private TransactionRepository transactionRepository;

        @InjectMocks
        private TransferService transferService;

        private Account fromAccount;
        private Account toAccount;

        @BeforeEach
        void setUp() {
                fromAccount = new Account();
                fromAccount.setId(1L);
                fromAccount.setAccountNumber("1234567890");
                fromAccount.setAccountHolderName("John Doe");
                fromAccount.setBalance(new BigDecimal("1000.00"));
                fromAccount.setCurrency("USD");
                fromAccount.setStatus("ACTIVE");

                toAccount = new Account();
                toAccount.setId(2L);
                toAccount.setAccountNumber("0987654321");
                toAccount.setAccountHolderName("Jane Smith");
                toAccount.setBalance(new BigDecimal("500.00"));
                toAccount.setCurrency("USD");
                toAccount.setStatus("ACTIVE");
        }

        @Test
        void testSuccessfulTransfer() {
                // Arrange
                BigDecimal transferAmount = new BigDecimal("300.00");

                when(accountRepository.findByAccountNumber("1234567890"))
                                .thenReturn(Optional.of(fromAccount));
                when(accountRepository.findByAccountNumber("0987654321"))
                                .thenReturn(Optional.of(toAccount));

                Transaction mockTransaction = new Transaction();
                mockTransaction.setTransactionId("test-txn-id");
                mockTransaction.setStatus("SUCCESS");

                when(transactionRepository.save(any(Transaction.class)))
                                .thenReturn(mockTransaction);

                // Act
                Transaction result = transferService.transfer(
                                "1234567890", "0987654321", transferAmount, "Test transfer");

                // Assert
                assertNotNull(result);
                assertEquals("SUCCESS", result.getStatus());
                assertEquals(new BigDecimal("700.00"), fromAccount.getBalance());
                assertEquals(new BigDecimal("800.00"), toAccount.getBalance());

                verify(accountRepository, times(2)).save(any(Account.class));
                verify(transactionRepository, times(1)).save(any(Transaction.class));
        }

        @Test
        void testTransferWithInsufficientFunds() {
                // Arrange
                BigDecimal transferAmount = new BigDecimal("1500.00");

                when(accountRepository.findByAccountNumber("1234567890"))
                                .thenReturn(Optional.of(fromAccount));
                when(accountRepository.findByAccountNumber("0987654321"))
                                .thenReturn(Optional.of(toAccount));
                when(transactionRepository.save(any(Transaction.class)))
                                .thenReturn(new Transaction());

                // Act & Assert
                assertThrows(InsufficientFundsException.class, () -> {
                        transferService.transfer(
                                        "1234567890", "0987654321", transferAmount, "Test transfer");
                });

                // Verify failed transaction was recorded
                verify(transactionRepository, times(1)).save(any(Transaction.class));
                verify(accountRepository, never()).save(any(Account.class));
        }

        @Test
        void testTransferWithNonExistentSourceAccount() {
                // Arrange
                when(accountRepository.findByAccountNumber(anyString()))
                                .thenReturn(Optional.empty());

                // Act & Assert
                assertThrows(AccountNotFoundException.class, () -> {
                        transferService.transfer(
                                        "9999999999", "0987654321",
                                        new BigDecimal("100.00"), "Test transfer");
                });
        }

        @Test
        void testTransferWithNonExistentDestinationAccount() {
                // Arrange
                when(accountRepository.findByAccountNumber("1234567890"))
                                .thenReturn(Optional.of(fromAccount));
                when(accountRepository.findByAccountNumber("0987654321"))
                                .thenReturn(Optional.empty());

                // Act & Assert
                assertThrows(AccountNotFoundException.class, () -> {
                        transferService.transfer(
                                        "1234567890", "0987654321",
                                        new BigDecimal("100.00"), "Test transfer");
                });
        }

        @Test
        void testTransferWithInactiveSourceAccount() {
                // Arrange
                fromAccount.setStatus("INACTIVE");

                when(accountRepository.findByAccountNumber("1234567890"))
                                .thenReturn(Optional.of(fromAccount));
                when(accountRepository.findByAccountNumber("0987654321"))
                                .thenReturn(Optional.of(toAccount));

                // Act & Assert
                assertThrows(IllegalStateException.class, () -> {
                        transferService.transfer(
                                        "1234567890", "0987654321",
                                        new BigDecimal("100.00"), "Test transfer");
                });
        }

        @Test
        void testTransferWithNegativeAmount() {
                // Arrange
                when(accountRepository.findByAccountNumber("1234567890"))
                                .thenReturn(Optional.of(fromAccount));
                when(accountRepository.findByAccountNumber("0987654321"))
                                .thenReturn(Optional.of(toAccount));

                // Act & Assert
                assertThrows(IllegalArgumentException.class, () -> {
                        transferService.transfer(
                                        "1234567890", "0987654321",
                                        new BigDecimal("-100.00"), "Test transfer");
                });
        }
}