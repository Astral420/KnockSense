# KnockSense Authentication Setup Instructions

## Overview
This Flutter application implements a faculty management system with authentication for three user types:
- **Students** - Microsoft OAuth with STI email (dy.xxxxxx@malolos.sti.edu.ph)
- **Teachers** - Microsoft OAuth with STI email (firstname.lastname@malolos.sti.edu.ph)
- **Admins** - Firebase email/password authentication

## Prerequisites

1. **Firebase Project Setup**
   - Create a Firebase project at https://console.firebase.google.com
   - Enable Authentication with Email/Password
   - Enable Realtime Database
   - Enable Cloud Storage
   - Download configuration files:
     - `google-services.json` for Android (place in `android/app/`)
     - `GoogleService-Info.plist` for iOS (place in `ios/Runner/`)

2. **Firebase Authentication Setup**
   - In Firebase Console, go to Authentication > Sign-in method
   - Enable Microsoft provider
   - Add your Microsoft Azure App details:
     - Application (client) ID
     - Application (client) secret
   - Configure authorized domains if needed

3. **Microsoft Azure App Registration** (for Firebase integration)
   - Go to https://portal.azure.com
   - Register a new application  
   - In "Redirect URIs", add your Firebase Auth domain:
     - `https://YOUR_PROJECT_ID.firebaseapp.com/__/auth/handler`
   - Enable Microsoft Graph API permissions:
     - `User.Read` (for basic profile)
     - `User.ReadBasic.All` (for profile photos)
   - Copy the Application (client) ID and secret for Firebase setup

## Configuration Steps

### 1. Configure Firebase
Ensure your Firebase configuration files are properly placed:
- Android: `android/app/google-services.json`
- iOS: `ios/Runner/GoogleService-Info.plist`

### 2. Configure Firebase Authentication
1. Go to Firebase Console > Authentication > Sign-in method
2. Enable Microsoft provider
3. Enter your Microsoft Azure App credentials
4. Save the configuration

### 3. Email Pattern Configuration
The authentication system automatically determines user roles based on email patterns:

- **Students**: `dy.{student_number}@malolos.sti.edu.ph`
  - Example: `dy.286593@malolos.sti.edu.ph`
  - Student number is extracted from the email

- **Teachers**: `{firstname}.{lastname}@malolos.sti.edu.ph`
  - Example: `john.doe@malolos.sti.edu.ph`

- **Admins**: Any email registered through Firebase Authentication
  - Must be created through the admin creation flow in the app

## Firebase Database Structure

The app uses Firebase Realtime Database with this structure:
```
users/
  {userId}/
    id: string
    email: string
    role: "student" | "teacher" | "admin"
    displayName: string
    profilePhotoUrl: string (optional)
    lastLoginAt: string (ISO date)
    studentNumber: string (for students only)
    department: string (for teachers, optional)
```

## Profile Photo Flow

1. User signs in with Microsoft OAuth
2. Microsoft Graph API retrieves user profile photo
3. Photo is uploaded to Firebase Cloud Storage
4. Storage URL is saved to user profile in Realtime Database
5. Cached network image displays the photo in the UI

## Testing the Authentication Flow

### Admin Login
1. Use the "Admin Login" button on the login page
2. Create an admin account with any email/password
3. Or login with existing admin credentials

### Microsoft OAuth (Students/Teachers)
1. Use the "Sign in with Microsoft" button
2. Firebase handles the OAuth flow automatically
3. Users authenticate with their Microsoft accounts
4. Profile photos are retrieved from Microsoft Graph API

## Current Limitations & Next Steps

1. **Error Handling**: Add more robust error handling for network failures, token expiration, etc.

2. **Token Management**: Firebase handles token refresh automatically, but you may want to add additional error handling.

3. **Offline Support**: Add offline capabilities and data synchronization.

4. **Additional Features**: The main pages (Admin, Teacher, Student) are basic dashboards - add actual functionality as needed.

## Dependencies Used

- `firebase_core` & `firebase_auth` - Firebase authentication with Microsoft provider
- `firebase_database` - Realtime database
- `firebase_storage` - Cloud storage for profile photos
- `flutter_riverpod` - State management
- `dio` - HTTP client for Microsoft Graph API
- `cached_network_image` - Efficient image loading

## Security Notes

1. Store sensitive configuration (client secrets, etc.) securely
2. Implement proper token validation and refresh mechanisms
3. Use HTTPS for all network communication
4. Validate user roles server-side for sensitive operations
5. Implement proper session management and logout

## Support

For issues with:
- Firebase setup: Check Firebase console and configuration files
- Microsoft OAuth: Verify Azure app registration and permissions
- Deep linking: Test with platform-specific tools
- Email patterns: Verify regex patterns match your institution's format
