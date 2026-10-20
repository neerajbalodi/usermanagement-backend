# user-management-backend (Day 3)

Spring Boot REST API:

| Method | URL          | What it does        |
|--------|--------------|---------------------|
| POST   | `/api/users` | Register a new user |
| GET    | `/api/users` | List all users (with a temporary photo link) |
| POST   | `/api/users/{id}/photo` | Upload / replace a user's photo (form field `file`, JPG/PNG/WEBP, max 5 MB) |

## Prerequisites
- Java 17+ (JDK 21 works)
- Maven
- PostgreSQL running on port 5432, with database `userdb` and user `appuser` / `appuser123`

## Run
```bash
mvn clean install
java -jar target/user-management-0.0.1-SNAPSHOT.jar
```

Create the database once (the `USERS` table is then created automatically):
```sql
CREATE USER appuser WITH PASSWORD 'appuser123';
CREATE DATABASE userdb OWNER appuser;
```

Database connection defaults to `localhost` / `userdb` / `appuser` / `appuser123`. To point at another
machine (e.g. the database EC2 instance), set environment variables before starting:
```bash
export DB_HOST=<database-private-ip>
export DB_USERNAME=<user>
export DB_PASSWORD=<password>
```

## Try it
```bash
curl -X POST http://localhost:8080/api/users \
  -H "Content-Type: application/json" \
  -d '{"name":"Asha","email":"asha@example.com","password":"secret123"}'

curl http://localhost:8080/api/users
```

## Photos (Day 2)
Photos are stored in a **private** S3 bucket; PostgreSQL only keeps the S3 key.
The API returns a pre-signed URL (valid 60 minutes) so the browser can show the photo.

Set before starting (on EC2 Ansible does this):
```bash
export S3_BUCKET=<bucket-name>
export AWS_REGION=ap-south-1
```
AWS credentials come from the EC2 IAM role (on a laptop: `aws configure`).
Without `S3_BUCKET` the app still runs; only photo upload is switched off.

## Cache (Day 3)
`GET /api/users` is cached in Redis (key `users::all`, expires after 10 minutes).
Registering a user or uploading a photo clears it. If Redis is down the app logs a
warning and reads from PostgreSQL instead.

On a laptop the cache is in memory (no Redis needed). To use Redis:
```bash
export CACHE_TYPE=redis
export REDIS_HOST=localhost
export REDIS_PASSWORD=<password>   # empty if your Redis has none
```
Watch it: the log prints `Cache MISS - loading users from PostgreSQL` only when
the database is really used. In Redis: `redis-cli -a <pw> GET users::all`, `TTL users::all`.
