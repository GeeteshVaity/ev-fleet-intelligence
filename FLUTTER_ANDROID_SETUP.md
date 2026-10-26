# Flutter and Android setup

This document lists the tool versions used by the project and the commands
needed to install and run it locally.

## Tested tool versions

| Tool | Required/tested version | Used by |
|---|---:|---|
| Flutter | 3.47.7, stable channel | Mobile application |
| Dart SDK | 3.13.5 | Flutter application |
| DevTools | 2.60.0 | Flutter debugging |
| Android SDK Platform | Android 36 (`android-36`) | Android compilation |
| Android Build Tools | 36.0.0 | Android packaging |
| Android Gradle Plugin | 9.1.0 | `evfleet_mobile/android/settings.gradle.kts` |
| Gradle wrapper | 9.3.1 | `evfleet_mobile/android/gradle/wrapper/gradle-wrapper.properties` |
| Kotlin Gradle plugin | 2.4.0 | Android build |
| Java for Android | JDK 17 | Android Gradle and Kotlin compilation |
| Java for backend | JDK 21 | Spring Boot backend (`backend/pom.xml`) |
| PostgreSQL | 18.x | Local backend database |

The Android module compiles Java and Kotlin with JVM target 17. The backend
requires Java 21, so install both JDKs if the mobile app and backend are run on
the same computer.

## Windows installation

### 1. Install Flutter

Install the stable Flutter SDK and add its `bin` directory to `PATH`.
The tested installation was:

```text
C:\src\flutter
```

Verify the installation:

```powershell
flutter --version
flutter doctor -v
```

Expected Flutter/Dart output:

```text
Flutter 3.47.7
Dart 3.13.5
```

### 2. Install Android Studio and Android SDK

Install Android Studio with the Android SDK, SDK Platform Tools, and Android
SDK Command-line Tools. In SDK Manager, install:

- Android SDK Platform 36
- Android SDK Build-Tools 36.0.0
- Android SDK Platform-Tools
- Android SDK Command-line Tools
- Android Emulator (only if an emulator is required)

The tested SDK location was:

```text
C:\Android\Sdk
```

Set `ANDROID_HOME` or `ANDROID_SDK_ROOT` to the SDK location if the installer
does not configure it automatically. Then accept the Android licenses:

```powershell
flutter doctor --android-licenses
```

Confirm that the Android toolchain is available:

```powershell
flutter doctor -v
```

### 3. Install Java

Install:

- Eclipse Temurin/OpenJDK 17 for the Android build.
- Eclipse Temurin/OpenJDK 21 for the Spring Boot backend.

Configure Flutter to use JDK 17:

```powershell
flutter config --jdk-dir="C:\Program Files\Eclipse Adoptium\jdk-17.0.20.101-hotspot"
```

Verify:

```powershell
flutter doctor -v
java -version
```

When running Maven, make sure `JAVA_HOME` points to JDK 21. For example, in a
PowerShell session:

```powershell
$env:JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-21"
$env:Path = "$env:JAVA_HOME\bin;$env:Path"
java -version
```

Use the actual installation directory on the computer.

## Install project dependencies

From the repository root:

```powershell
Set-Location .\evfleet_mobile
flutter pub get
```

The Dart SDK constraint is `^3.13.5`. The main application dependencies are
Riverpod, GoRouter, Dio, secure storage, Geolocator, cached network images,
SharedPreferences, and Intl; their constraints are recorded in
`evfleet_mobile/pubspec.yaml`.

## Run the Android app

### Physical Android phone

1. Enable Developer options and USB debugging.
2. Connect the phone and approve the computer authorization prompt.
3. Keep the phone and computer on the same network when using the local
   backend.
4. Find the computer's LAN IPv4 address with:

   ```powershell
   Get-NetIPAddress -AddressFamily IPv4
   ```

5. Start the app using that address:

   ```powershell
   Set-Location .\evfleet_mobile
   flutter run -d <device-id> `
     --dart-define=API_BASE_URL=http://<computer-lan-ip>:8080
   ```

   Example:

   ```powershell
   flutter run -d RZCTA11J3GY `
     --dart-define=API_BASE_URL=http://172.18.2.19:8080
   ```

### Android emulator

The Android emulator reaches the host computer through `10.0.2.2`:

```powershell
Set-Location .\evfleet_mobile
flutter run -d emulator-5554 `
  --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

The app also converts a configured `localhost` URL to `10.0.2.2` on Android.
For a physical phone, always use the computer's LAN address instead.

### Desktop or web

```powershell
Set-Location .\evfleet_mobile
flutter run -d windows `
  --dart-define=API_BASE_URL=http://localhost:8080
```

## Run the backend

The backend uses Java 21, PostgreSQL, and port 8080.

1. Start the PostgreSQL service and create the `evfleetdb` database.
2. Check the credentials in:
   `backend/src/main/resources/application.properties`.
3. Start Spring Boot:

   ```powershell
   $env:JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-21"
   $env:Path = "$env:JAVA_HOME\bin;$env:Path"
   Set-Location .\backend
   .\mvnw.cmd spring-boot:run
   ```

4. Confirm port 8080 is listening:

   ```powershell
   Get-NetTCPConnection -LocalPort 8080 -State Listen
   ```

The backend is configured to listen on all interfaces so a phone on the same
LAN can connect. Windows Firewall may still require an inbound rule for TCP
port 8080.

## Validation commands

Run these from `evfleet_mobile`:

```powershell
flutter analyze
flutter test
```

Run backend tests from `backend`:

```powershell
.\mvnw.cmd test
```

## Common connection problems

| Error | Fix |
|---|---|
| `Connection refused` with `localhost` on a physical phone | Use the computer LAN IP, not `localhost`. |
| `Connection refused` with an emulator | Use `10.0.2.2:8080`. |
| Backend cannot start | Verify PostgreSQL is running and use JDK 21 for Maven. |
| Android build uses the wrong Java version | Run `flutter config --jdk-dir="<JDK 17 path>"`. |
| Phone cannot reach port 8080 | Check both devices are on the same network and allow TCP 8080 through Windows Firewall. |
| `flutter doctor` reports Visual Studio missing | Only required for Windows desktop builds; it is not required for Android builds. |

