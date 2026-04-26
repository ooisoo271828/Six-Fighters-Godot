## ADDED Requirements

### Requirement: CLI entry point with argument parsing
The broker-server SHALL provide a CLI entry point using Commander.js that accepts the following options: `--tcp-port` (default 5301), `--http-port` (default 5302), `--host` (default "localhost"), and `--auth-token` (optional). When the CLI starts, it SHALL launch both the TCP server and HTTP server, and print their listening addresses to stdout.

#### Scenario: Start with default options
- **WHEN** the CLI is invoked with no arguments
- **THEN** the TCP server SHALL listen on `localhost:5301`, the HTTP server SHALL listen on `localhost:5302`, and an auto-generated auth token SHALL be printed to stdout

#### Scenario: Start with custom ports and host
- **WHEN** the CLI is invoked with `--tcp-port 6001 --http-port 6002 --host 0.0.0.0`
- **THEN** the TCP server SHALL listen on `0.0.0.0:6001` and the HTTP server SHALL listen on `0.0.0.0:6002`

#### Scenario: Start with custom auth token
- **WHEN** the CLI is invoked with `--auth-token my-secret-token`
- **THEN** the HTTP server SHALL use `my-secret-token` for authentication and SHALL NOT print an auto-generated token

#### Scenario: Start without auth token specified
- **WHEN** the CLI is invoked without `--auth-token`
- **THEN** a random auth token SHALL be generated (at least 32 characters), printed to stdout with a descriptive message, and used for HTTP API authentication

### Requirement: Node.js project setup
The broker-server SHALL be a Node.js project in the `broker-server/` directory managed by npm, with TypeScript as the language, Vite as the build tool (library mode), and `commander` and `express` as production dependencies. The project SHALL include a `.gitignore` that excludes `node_modules/`, `dist/`, and other generated files.

#### Scenario: Project structure verification
- **WHEN** the `broker-server/` directory is inspected
- **THEN** it SHALL contain `package.json`, `tsconfig.json`, `vite.config.ts`, `.gitignore`, and a `src/` directory with TypeScript source files

### Requirement: Graceful shutdown
The broker-server SHALL handle SIGINT (Ctrl+C) and SIGTERM signals to gracefully shut down both the TCP server and HTTP server, closing all active plugin connections before exiting.

#### Scenario: SIGINT received
- **WHEN** the process receives SIGINT while plugins are connected
- **THEN** all TCP connections SHALL be closed, both servers SHALL stop accepting new connections, and the process SHALL exit with code 0
