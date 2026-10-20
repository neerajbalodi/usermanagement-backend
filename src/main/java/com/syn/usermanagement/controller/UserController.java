package com.syn.usermanagement.controller;

import com.syn.usermanagement.dto.UserResponse;
import com.syn.usermanagement.entity.User;
import com.syn.usermanagement.service.UserService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.List;

@RestController
@RequestMapping("/api/users")
@CrossOrigin(origins = "*")   // allow the Angular app (any host/port) to call this API
@RequiredArgsConstructor
public class UserController {

    private final UserService userService;

    // POST http://localhost:8080/api/users   -> register a new user
    @PostMapping
    public ResponseEntity<UserResponse> registerUser(@Valid @RequestBody User user) {
        return ResponseEntity.status(HttpStatus.CREATED).body(userService.registerUser(user));
    }

    // GET http://localhost:8080/api/users    -> list all users (with photo links)
    @GetMapping
    public ResponseEntity<List<UserResponse>> getAllUsers() {
        return ResponseEntity.ok(userService.getAllUsers());
    }

    // POST http://localhost:8080/api/users/{id}/photo   (form field "file") -> upload / replace photo
    @PostMapping(value = "/{id}/photo", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<UserResponse> uploadPhoto(@PathVariable("id") Long id,
                                                    @RequestParam("file") MultipartFile file) throws IOException {
        return ResponseEntity.ok(userService.uploadPhoto(id, file));
    }
}
