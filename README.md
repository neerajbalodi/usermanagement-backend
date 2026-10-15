# user-management-backend (Day 1)

Spring Boot REST API with two endpoints:

| Method | URL          | What it does        |
|--------|--------------|---------------------|
| POST   | `/api/users` | Register a new user |
| GET    | `/api/users` | List all users      |

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
