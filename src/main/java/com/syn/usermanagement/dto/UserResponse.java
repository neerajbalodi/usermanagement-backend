package com.syn.usermanagement.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.io.Serializable;

/**
 * What the API returns for a user.
 * No password, and instead of the S3 key a temporary (pre-signed) link to the photo.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class UserResponse implements Serializable {
    private Long id;
    private String name;
    private String email;
    private String photoUrl;   // null when the user has no photo
}
