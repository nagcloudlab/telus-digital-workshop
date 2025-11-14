package com.workshop.moneytransfer.controller;

import com.workshop.moneytransfer.dto.TransferRequest;
import com.workshop.moneytransfer.model.Account;
import com.workshop.moneytransfer.service.AccountService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.math.BigDecimal;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@Tag("integration")
@SpringBootTest
@AutoConfigureMockMvc
class TransferControllerIntegrationTest {

        @Autowired
        private MockMvc mockMvc;

        @Autowired
        private ObjectMapper objectMapper;

        @Autowired
        private AccountService accountService;

        private String fromAccountNumber;
        private String toAccountNumber;

        @BeforeEach
        void setUp() {
                // Create test accounts
                Account fromAccount = accountService.createAccount("John Doe", new BigDecimal("1000.00"));
                Account toAccount = accountService.createAccount("Jane Smith", new BigDecimal("500.00"));

                fromAccountNumber = fromAccount.getAccountNumber();
                toAccountNumber = toAccount.getAccountNumber();
        }

        @Test
        void testSuccessfulTransfer() throws Exception {
                TransferRequest request = new TransferRequest(
                                fromAccountNumber,
                                toAccountNumber,
                                new BigDecimal("300.00"),
                                "Integration test transfer");

                mockMvc.perform(post("/api/transfers")
                                .contentType(MediaType.APPLICATION_JSON)
                                .content(objectMapper.writeValueAsString(request)))
                                .andExpect(status().isCreated())
                                .andExpect(jsonPath("$.status").value("SUCCESS"))
                                .andExpect(jsonPath("$.amount").value(300.00))
                                .andExpect(jsonPath("$.fromAccountNumber").value(fromAccountNumber))
                                .andExpect(jsonPath("$.toAccountNumber").value(toAccountNumber));
        }

        @Test
        void testTransferWithInsufficientFunds() throws Exception {
                TransferRequest request = new TransferRequest(
                                fromAccountNumber,
                                toAccountNumber,
                                new BigDecimal("2000.00"),
                                "Insufficient funds test");

                mockMvc.perform(post("/api/transfers")
                                .contentType(MediaType.APPLICATION_JSON)
                                .content(objectMapper.writeValueAsString(request)))
                                .andExpect(status().isBadRequest())
                                .andExpect(jsonPath("$.code").value("INSUFFICIENT_FUNDS"));
        }

        @Test
        void testTransferWithInvalidAccountNumber() throws Exception {
                TransferRequest request = new TransferRequest(
                                "9999999999",
                                toAccountNumber,
                                new BigDecimal("100.00"),
                                "Invalid account test");

                mockMvc.perform(post("/api/transfers")
                                .contentType(MediaType.APPLICATION_JSON)
                                .content(objectMapper.writeValueAsString(request)))
                                .andExpect(status().isNotFound())
                                .andExpect(jsonPath("$.code").value("ACCOUNT_NOT_FOUND"));
        }

        @Test
        void testGetTransactionHistory() throws Exception {
                // First make a transfer
                TransferRequest request = new TransferRequest(
                                fromAccountNumber,
                                toAccountNumber,
                                new BigDecimal("100.00"),
                                "History test transfer");

                mockMvc.perform(post("/api/transfers")
                                .contentType(MediaType.APPLICATION_JSON)
                                .content(objectMapper.writeValueAsString(request)))
                                .andExpect(status().isCreated());

                // Then get history
                mockMvc.perform(get("/api/transfers/history/" + fromAccountNumber))
                                .andExpect(status().isOk())
                                .andExpect(jsonPath("$").isArray())
                                .andExpect(jsonPath("$[0].fromAccountNumber").value(fromAccountNumber));
        }
}