## ADDED Requirements

### Requirement: Connection status display
The executor dock SHALL display a connection status bar at the top of the panel showing the current connection state to the broker-server. The status SHALL show "Connected" (green) or "Disconnected" (red).

#### Scenario: Plugin connected to broker
- **WHEN** the broker client is connected and registered
- **THEN** the status bar SHALL display "Connected" in green text

#### Scenario: Plugin disconnected from broker
- **WHEN** the broker client is not connected
- **THEN** the status bar SHALL display "Disconnected" in red text

#### Scenario: Connection state transition
- **WHEN** the connection state changes from connected to disconnected or vice versa
- **THEN** the status display SHALL update immediately to reflect the new state

### Requirement: Registration ID display with copy support
The executor dock SHALL display the registration ID below the connection status when connected. The ID SHALL be selectable and copyable by the user.

#### Scenario: ID displayed when connected
- **WHEN** the plugin is connected and has a registration ID
- **THEN** the dock SHALL display "ID: <registration-id>" in a selectable/copyable label

#### Scenario: ID hidden when disconnected
- **WHEN** the plugin is not connected
- **THEN** the ID display SHALL be hidden or show a placeholder

### Requirement: Broker-server address configuration
The plugin SHALL read broker-server connection settings from ProjectSettings under `hastur_operation/broker_host` (default "localhost") and `hastur_operation/broker_port` (default 5301). These settings SHALL be registered in ProjectSettings on plugin enable.

#### Scenario: Default broker address
- **WHEN** no custom broker settings are configured
- **THEN** the plugin SHALL attempt to connect to `localhost:5301`

#### Scenario: Custom broker address
- **WHEN** `hastur_operation/broker_host` is set to "192.168.1.100" and `hastur_operation/broker_port` is set to 6001
- **THEN** the plugin SHALL attempt to connect to `192.168.1.100:6001`
