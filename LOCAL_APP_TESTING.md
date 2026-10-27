# Run and test the app locally

This guide covers the complete local workflow for the EV Fleet Intelligence
backend and the Voltway Flutter frontend on Windows.

## 1. Prerequisites

Install and verify:

| Tool | Version |
|---|---|
| Git | Any recent version |
| Java | JDK 21 for the Spring Boot backend |
| PostgreSQL | 18.x or a compatible recent version |
| Flutter | 3.47.7 stable |
| Dart | 3.13.5 (included with the tested Flutter version) |
| Android Studio and Android SDK | Only required for Android |

For Android builds, configure Flutter to use JDK 17. The backend must use JDK
21. See [FLUTTER_ANDROID_SETUP.md](./FLUTTER_ANDROID_SETUP.md) for Android SDK,
emulator, device, and Java installation details.

Check the tools:

```powershell
java -version
flutter --version
flutter doctor -v
psql --version
```

## 2. Create the local PostgreSQL database

Start the PostgreSQL service, then create the database once. Replace `postgres`
with your local PostgreSQL username if necessary.

```powershell
psql -U postgres -c "CREATE DATABASE evfleetdb;"
```

If PostgreSQL reports that `evfleetdb` already exists, continue. The backend
uses Hibernate `ddl-auto=update` in local development and creates/updates its
tables on startup.

The backend defaults are:

```text
Database: evfleetdb
Host: localhost
Port: 5432
Username: postgres
Password: jay1818
API: http://localhost:8080
```

For the currently connected Android phone, use these tested local-network
values:

```text
Computer Wi-Fi IP: 10.10.22.63
Android device ID: 6f3f4a21
Phone API: http://10.10.22.63:8080
```

Do not commit passwords. Set the database values in the current PowerShell
session before starting the backend:

```powershell
$env:SPRING_DATASOURCE_URL = "jdbc:postgresql://localhost:5432/evfleetdb"
$env:SPRING_DATASOURCE_USERNAME = "postgres"
$env:SPRING_DATASOURCE_PASSWORD = "jay1818"
```

## 3. Start the backend

Open a PowerShell terminal at the repository root:

```powershell
Set-Location .\backend
.\mvnw.cmd spring-boot:run
```

Leave this terminal running. A successful startup listens on port `8080`.
The backend is configured to listen on all interfaces so an Android phone on
the same LAN can reach it.

To confirm that the port is listening from a second terminal:

```powershell
Get-NetTCPConnection -LocalPort 8080 -State Listen
```

There is no dedicated health endpoint. Use the public stations endpoint as the
backend smoke check:

```powershell
curl.exe -i http://localhost:8080/api/stations
```

Expected result: HTTP `200 OK` and a JSON array. An empty array is valid when
no stations have been created yet.

## 4. Run backend tests

Backend tests use an isolated in-memory H2 database, so PostgreSQL does not
need to be running for this command:

```powershell
Set-Location .\backend
.\mvnw.cmd test
```

Run this after backend changes. A successful run ends with `BUILD SUCCESS`.

## 5. Create test data through the local API

The local API uses the `X-User-Sub` header as a development identity boundary.
Use a stable value such as `demo-user`; this is not a replacement for
production Cognito JWT authentication.

Create or update a demo profile:

```powershell
curl.exe -i -X POST http://localhost:8080/api/users/me `
  -H "Content-Type: application/json" `
  -H "X-User-Sub: demo-user" `
  -d '{"fullName":"Demo User","email":"demo@example.com","phone":"5550100"}'
```

Create a vehicle:

```powershell
curl.exe -i -X POST http://localhost:8080/api/vehicles `
  -H "Content-Type: application/json" `
  -H "X-User-Sub: demo-user" `
  -d '{"vehicleType":"CAR","brand":"Tesla","model":"Model 3","registrationNumber":"EV-001","batteryCapacityKwh":60,"connectorType":"CCS2"}'
```

Verify the profile and vehicle:

```powershell
curl.exe -i http://localhost:8080/api/users/me `
  -H "X-User-Sub: demo-user"

curl.exe -i http://localhost:8080/api/vehicles `
  -H "X-User-Sub: demo-user"
```

Useful public station checks:

```powershell
curl.exe -i http://localhost:8080/api/stations

curl.exe -i "http://localhost:8080/api/stations/nearby?latitude=19.0760&longitude=72.8777&radiusKm=10"
```

## 6. Install and run the Flutter frontend

Open a second PowerShell terminal at the repository root:

```powershell
Set-Location .\evfleet_mobile
flutter pub get
flutter devices
```

### Windows desktop

Use this when Windows desktop support is installed:

```powershell
flutter run -d windows `
  --dart-define=API_BASE_URL=http://localhost:8080
```

### Android emulator

Start an emulator from Android Studio or with `flutter emulators`, then run:

```powershell
flutter run -d <emulator-device-id> `
  --dart-define=API_BASE_URL=http://localhost:8080
```

The app automatically changes Android `localhost` to `10.0.2.2`, which is the
Android emulator address for the host computer.

### Physical Android phone

Enable USB debugging, connect the phone, and keep it on the same network as
the computer. The current computer Wi-Fi address is `10.10.22.63`, and the
connected phone is `6f3f4a21`. To check the values again:

```powershell
Get-NetIPAddress -AddressFamily IPv4
flutter devices
```

Run the app on the connected phone:

```powershell
flutter run -d 6f3f4a21 `
  --dart-define=API_BASE_URL=http://10.10.22.63:8080
```

If the phone cannot connect, allow inbound TCP port `8080` through Windows
Firewall.

### Demo-only frontend mode

To run the UI without the backend:

```powershell
flutter run -d 6f3f4a21
```

When `API_BASE_URL` is omitted, the app intentionally uses in-memory demo
data. This is useful for visual testing, but it does not verify backend
integration. Some feature repositories are still demo/mock implementations,
and authentication is explicitly demo-mode until Cognito is configured.

## 7. Frontend validation and tests

Run from `evfleet_mobile`:

```powershell
dart format lib test
flutter analyze
flutter test
```

To run the widget test only:

```powershell
flutter test test/widget_test.dart
```

## 8. End-to-end local smoke test

Use this order for a full local check:

1. Start PostgreSQL and create `evfleetdb`.
2. Start the backend with `.\mvnw.cmd spring-boot:run`.
3. Confirm `curl.exe http://localhost:8080/api/stations` returns `200`.
4. Create the demo profile and vehicle using the commands above.
5. Confirm `GET /api/users/me` and `GET /api/vehicles` return the created data.
6. Start Flutter with the correct `API_BASE_URL` for the target device.
7. Open the app and check the home, explore, station details, bookings,
   vehicles, and profile screens.
8. Run `flutter analyze`, `flutter test`, and `.\mvnw.cmd test`.

## 9. Troubleshooting

| Problem | Fix |
|---|---|
| Backend cannot connect to PostgreSQL | Confirm PostgreSQL is running, the database exists, and the three `SPRING_DATASOURCE_*` variables are set in the same terminal that starts Maven. |
| Port 8080 is already in use | Find the process with `Get-NetTCPConnection -LocalPort 8080`; stop the specific process or choose another server port and use the same port in `API_BASE_URL`. |
| Android emulator gets connection refused | Use `--dart-define=API_BASE_URL=http://localhost:8080`; the app maps it to `10.0.2.2`, or pass `http://10.0.2.2:8080` directly. |
| Physical phone gets connection refused | Use the computer LAN IP, keep both devices on the same network, and allow TCP 8080 through Windows Firewall. |
| Flutter runs but shows demo data | `API_BASE_URL` was omitted, or the feature has not yet been migrated from its mock repository. |
| Android build selects the wrong Java version | Configure Flutter with `flutter config --jdk-dir="<JDK 17 path>"`; use JDK 21 for Maven. |
| API returns `400` for a user route | Include `X-User-Sub`. For create/update requests, also provide the required JSON fields. |
| `flutter doctor` reports missing Visual Studio | This is only required for Windows desktop builds; it is not required for Android. |

## Related documentation

- [Root project README](./README.md)
- [Flutter Android setup](./FLUTTER_ANDROID_SETUP.md)
- [Flutter project README](./evfleet_mobile/README.md)
