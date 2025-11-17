package com.workshop.moneytransfer.config;

import io.micrometer.core.aop.TimedAspect;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.Timer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class MetricsConfig {

    @Bean
    public TimedAspect timedAspect(MeterRegistry registry) {
        return new TimedAspect(registry);
    }

    @Bean
    public Counter transferCounter(MeterRegistry registry) {
        return Counter.builder("money.transfer.count")
                .description("Total number of money transfers")
                .tag("type", "transfer")
                .register(registry);
    }

    @Bean
    public Timer transferTimer(MeterRegistry registry) {
        return Timer.builder("money.transfer.duration")
                .description("Money transfer processing time")
                .tag("type", "transfer")
                .register(registry);
    }

    @Bean
    public Counter transferSuccessCounter(MeterRegistry registry) {
        return Counter.builder("money.transfer.success")
                .description("Successful money transfers")
                .tag("type", "transfer")
                .tag("status", "success")
                .register(registry);
    }

    @Bean
    public Counter transferFailureCounter(MeterRegistry registry) {
        return Counter.builder("money.transfer.failure")
                .description("Failed money transfers")
                .tag("type", "transfer")
                .tag("status", "failure")
                .register(registry);
    }

    @Bean
    public Counter accountCreationCounter(MeterRegistry registry) {
        return Counter.builder("money.account.created")
                .description("Total accounts created")
                .tag("type", "account")
                .register(registry);
    }
}
