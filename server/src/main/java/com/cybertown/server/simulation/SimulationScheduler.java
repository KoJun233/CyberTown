package com.cybertown.server.simulation;

import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
public class SimulationScheduler {

    private final SimulationService simulationService;

    public SimulationScheduler(SimulationService simulationService) {
        this.simulationService = simulationService;
    }

    @Scheduled(cron = "0 0 6 * * *", zone = "${cybertown.town-zone:Asia/Shanghai}")
    void morning() {
        simulationService.runSlot(TimeSlot.MORNING);
    }

    @Scheduled(cron = "0 0 12 * * *", zone = "${cybertown.town-zone:Asia/Shanghai}")
    void afternoon() {
        simulationService.runSlot(TimeSlot.AFTERNOON);
    }

    @Scheduled(cron = "0 0 18 * * *", zone = "${cybertown.town-zone:Asia/Shanghai}")
    void evening() {
        simulationService.runSlot(TimeSlot.EVENING);
    }

    @Scheduled(cron = "0 0 22 * * *", zone = "${cybertown.town-zone:Asia/Shanghai}")
    void night() {
        simulationService.runSlot(TimeSlot.NIGHT);
    }
}
