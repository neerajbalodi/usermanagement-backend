package com.syn.usermanagement.controller;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

/**
 * Day 4: an endpoint that deliberately burns CPU, so the class can watch
 * the Horizontal Pod Autoscaler add pods. (The cached user list is too cheap.)
 *
 *   GET /api/demo/cpu?millis=200
 */
@RestController
@RequestMapping("/api/demo")
@CrossOrigin(origins = "*")
public class DemoController {

    @GetMapping("/cpu")
    public ResponseEntity<Map<String, Object>> burnCpu(@RequestParam(name = "millis", defaultValue = "200") long millis) {
        long limit = Math.min(Math.max(millis, 1), 2000);   // between 1 ms and 2 s
        long end = System.nanoTime() + limit * 1_000_000;
        double x = 0;
        while (System.nanoTime() < end) {
            x += Math.sqrt(x + 1);   // pointless maths = CPU work
        }
        return ResponseEntity.ok(Map.of(
                "workedMillis", limit,
                "pod", System.getenv().getOrDefault("HOSTNAME", "local"),
                "result", (long) x));
    }
}
