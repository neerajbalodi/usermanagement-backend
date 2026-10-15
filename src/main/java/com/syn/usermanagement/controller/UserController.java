package com.syn.usermanagement.controller;

import com.syn.usermanagement.entity.User;
import com.syn.usermanagement.service.UserService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/users")
@CrossOrigin(origins = "*")   // allow the Angular app (any host/port) to call this API
@RequiredArgsConstructor
public class UserController {

    private final UserService userService;

    // POST http://localhost:8080/api/users   -> register a new user
    @PostMapping
    public ResponseEntity<User> registerUser(@Valid @RequestBody User user) {
        User savedUser = userService.registerUser(user);
        return ResponseEntity.status(HttpStatus.CREATED).body(savedUser);
    }

    // GET http://localhost:8080/api/users    -> list all users
    @GetMapping
    public ResponseEntity<List<User>> getAllUsers() {
        return ResponseEntity.ok(userService.getAllUsers());
    }
}
