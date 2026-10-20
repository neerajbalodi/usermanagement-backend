package com.syn.usermanagement.service;

import com.syn.usermanagement.dto.UserResponse;
import com.syn.usermanagement.entity.User;
import com.syn.usermanagement.exception.EmailAlreadyExistsException;
import com.syn.usermanagement.exception.InvalidPhotoException;
import com.syn.usermanagement.exception.PhotoStorageUnavailableException;
import com.syn.usermanagement.exception.ResourceNotFoundException;
import com.syn.usermanagement.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class UserService {

    /** Day 3: name of the cache that holds the user list (Redis key: users::all) */
    public static final String USERS_CACHE = "users";

    private static final Set<String> ALLOWED_TYPES = Set.of("image/jpeg", "image/png", "image/webp");

    private final UserRepository userRepository;
    private final PhotoStorageService photoStorage;

    // A new user changes the list -> throw the cached list away
    @CacheEvict(value = USERS_CACHE, allEntries = true)
    public UserResponse registerUser(User user) {
        if (userRepository.existsByEmail(user.getEmail())) {
            throw new EmailAlreadyExistsException("Email already exists: " + user.getEmail());
        }
        user.setPhotoKey(null);
        return toResponse(userRepository.save(user));
    }

    // First call: runs this method (database) and stores the result in the cache.
    // Next calls (within the TTL): served from the cache, this method does not run at all.
    // Note: the photo links inside are valid for 60 minutes, longer than the 10-minute cache TTL.
    @Cacheable(value = USERS_CACHE, key = "'all'")
    public List<UserResponse> getAllUsers() {
        log.info("Cache MISS - loading users from PostgreSQL");
        return userRepository.findAll(Sort.by("id")).stream()
                .map(this::toResponse)
                .collect(Collectors.toCollection(ArrayList::new));
    }

    // A new photo changes the list too
    @CacheEvict(value = USERS_CACHE, allEntries = true)
    public UserResponse uploadPhoto(Long userId, MultipartFile file) throws IOException {
        if (!photoStorage.isEnabled()) {
            throw new PhotoStorageUnavailableException("Photo storage (S3) is not configured on this server");
        }
        if (file == null || file.isEmpty()) {
            throw new InvalidPhotoException("Please choose a photo to upload");
        }
        if (!ALLOWED_TYPES.contains(file.getContentType())) {
            throw new InvalidPhotoException("Only JPG, PNG or WEBP images are allowed");
        }

        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found with id: " + userId));

        String oldKey = user.getPhotoKey();
        user.setPhotoKey(photoStorage.upload(userId, file));
        User saved = userRepository.save(user);
        photoStorage.delete(oldKey);   // one photo per user: remove the previous one

        return toResponse(saved);
    }

    private UserResponse toResponse(User user) {
        return new UserResponse(
                user.getId(),
                user.getName(),
                user.getEmail(),
                photoStorage.presignedUrl(user.getPhotoKey()));
    }
}
