# EV Fleet Intelligence backend deployment

## Prerequisites

- Java 21
- PostgreSQL 14 or newer locally, or Amazon RDS for PostgreSQL
- The Maven wrapper in this directory
- An existing Cognito user pool and app client

## Environment variables

Required for a production process:

```text
SPRING_PROFILES_ACTIVE=prod
DB_URL=jdbc:postgresql://<rds-endpoint>:5432/evfleetdb?sslmode=verify-full
DB_USERNAME=<application-user>
DB_PASSWORD=<secret>
COGNITO_ENABLED=true
COGNITO_ISSUER_URI=https://cognito-idp.<region>.amazonaws.com/<user-pool-id>
FRONTEND_ORIGIN=https://<frontend-origin>
```

Optional settings include `SERVER_PORT` (default `8080`), `DB_POOL_MAX_SIZE`
(default `10`), `DB_POOL_MIN_IDLE` (default `2`), and
`DB_POOL_CONNECTION_TIMEOUT_MS` (default `30000`). Never commit the password
or a real Cognito issuer to source control.

## Local PostgreSQL

Create a database and application user using an administrative PostgreSQL
connection, then set `DB_URL`, `DB_USERNAME`, and `DB_PASSWORD`. Local defaults
are `jdbc:postgresql://localhost:5432/evfleetdb` and user `postgres`.

```powershell
$env:DB_URL = "jdbc:postgresql://localhost:5432/evfleetdb"
$env:DB_USERNAME = "postgres"
$env:DB_PASSWORD = "<local-password>"
$env:COGNITO_ENABLED = "true"
$env:COGNITO_ISSUER_URI = "https://cognito-idp.<region>.amazonaws.com/<user-pool-id>"
.\mvnw.cmd spring-boot:run
```

The default profile uses Hibernate `ddl-auto=update` for local development.
The `prod` profile enables Flyway and Hibernate schema validation. Flyway
creates the versioned schema from `src/main/resources/db/migration` on an
empty database. Existing compatible schemas are baselined; back up existing
data before startup and investigate validation failures.

## Build and test

```powershell
.\mvnw.cmd test
.\mvnw.cmd clean package
java -jar target/backend-0.0.1-SNAPSHOT.jar
```

## EC2 and systemd

Copy the JAR to `/opt/ev-fleet-intelligence/backend/` and create a protected
environment file at `/etc/ev-fleet-intelligence/backend.env`:

```text
SPRING_PROFILES_ACTIVE=prod
DB_URL=jdbc:postgresql://<rds-endpoint>:5432/evfleetdb?sslmode=verify-full
DB_USERNAME=<application-user>
DB_PASSWORD=<secret>
COGNITO_ENABLED=true
COGNITO_ISSUER_URI=https://cognito-idp.<region>.amazonaws.com/<user-pool-id>
FRONTEND_ORIGIN=https://<frontend-origin>
```

```ini
[Unit]
Description=EV Fleet Intelligence API
After=network-online.target
Wants=network-online.target

[Service]
User=evfleet
WorkingDirectory=/opt/ev-fleet-intelligence/backend
EnvironmentFile=/etc/ev-fleet-intelligence/backend.env
ExecStart=/usr/bin/java -jar /opt/ev-fleet-intelligence/backend/backend-0.0.1-SNAPSHOT.jar
Restart=on-failure
RestartSec=5
SuccessExitStatus=143

[Install]
WantedBy=multi-user.target
```

Restrict the environment file (`root:evfleet`, mode `0640`), then run:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now ev-fleet-intelligence
sudo systemctl status ev-fleet-intelligence
sudo journalctl -u ev-fleet-intelligence -f
sudo systemctl restart ev-fleet-intelligence
```

## RDS, security groups, and health

Use an RDS private subnet and allow inbound TCP 5432 only from the EC2
security group. Allow TCP 8080 to EC2 only from the load balancer security
group; expose HTTPS at the load balancer. With `sslmode=verify-full`, install
the current RDS CA bundle on the EC2 host and use the RDS hostname, not an IP.

The public health URL is:

```text
https://<api-host>/actuator/health
```

The endpoint is intentionally the only exposed actuator endpoint. A valid
Cognito **access token** is required for `/api/users/me`, `/api/vehicles`,
bookings, and other protected routes. The Flutter build must use:

```text
--dart-define=API_BASE_URL=https://<api-host>
```

Do not use `X-User-Sub`; profile ownership is derived from the verified
Cognito JWT `sub` claim.
