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
}
