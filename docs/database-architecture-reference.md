# Database Architecture Reference

## **🎯 Overview**

The Intelligent DataOps Platform uses a **polyglot persistence architecture** with three specialized database systems, each optimized for specific use cases and access patterns. This reference provides a comprehensive overview of all database schemas, their relationships, and usage patterns.

## **🏗️ Multi-Database Architecture**

```
┌─────────────────────────────────────────────────────────────────┐
│                    AUTHENTICATION LAYER                        │
├─────────────────────────────────────────────────────────────────┤
│  Firebase Authentication ──→ JWT Tokens ──→ Custom Claims      │
│  • User Registration/Login  • OAuth Providers  • Session Mgmt  │
└─────────────────────────────┬───────────────────────────────────┘
                              │
┌─────────────────────────────┼───────────────────────────────────┐
│                    DATA INGESTION LAYER                        │
├─────────────────────────────┼───────────────────────────────────┤
│  Pub/Sub Topics ──→ Dataflow Pipelines ──→ Multiple Outputs    │
└─────────┬──────────────────┬──────────────────┬─────────────────┘
          │                  │                  │
          ▼                  ▼                  ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│   BigQuery      │ │   Firestore     │ │   Cloud SQL     │
│                 │ │                 │ │                 │
│ • Analytics     │ │ • Real-time     │ │ • Business      │
│ • Reporting     │ │ • Live Tracking │ │   Profiles      │
│ • ML Training   │ │ • Notifications │ │ • Configuration │
│ • Long-term     │ │ • Dashboard     │ │ • Transactions  │
│   Storage       │ │   Updates       │ │ • Business Logic│
└─────────────────┘ └─────────────────┘ └─────────────────┘
                              ▲                  ▲
                              │                  │
                    ┌─────────┴──────────────────┴─────────┐
                    │     Firebase UID Links All Data     │
                    └──────────────────────────────────────┘
```

## **📊 Database Comparison Matrix**

| Aspect | Firebase Auth | BigQuery | Firestore | Cloud SQL |
|--------|---------------|----------|-----------|-----------|
| **Primary Use Case** | Authentication | Analytics & Reporting | Real-time Operations | Business Data |
| **Data Model** | User Auth/Claims | Columnar/Analytical | Document/NoSQL | Relational/SQL |
| **Query Language** | SDK/REST API | SQL | NoSQL/JavaScript | SQL |
| **Consistency** | Strong | Eventually Consistent | Eventually Consistent | ACID Compliant |
| **Scalability** | Automatic | Petabyte Scale | Auto-scaling | Vertical/Read Replicas |
| **Real-time Updates** | Immediate | Batch/Streaming | Sub-second | Immediate |
| **Cost Model** | Pay-per-use | Pay-per-query | Pay-per-operation | Fixed instance cost |
| **Best For** | User management | Complex analytics | Live dashboards | Business relationships |

## **🔄 Data Flow Patterns**

### **Primary Data Flow**
```
IoT Telemetry ──→ Pub/Sub ──→ Dataflow ──┬──→ BigQuery (Historical)
                                          ├──→ Firestore (Real-time)
                                          └──→ Cloud SQL (Metadata)
```

### **Cross-Database Relationships**

#### **Vehicle Data Relationships**
```sql
-- Cloud SQL: Master vehicle data
vehicles.vehicle_identifier = "VH001"

-- Firestore: Real-time status
/vehicles/VH001 {
  currentStatus: {...},
  specifications: {...}
}

-- BigQuery: Historical telemetry
iot_telemetry.vehicle_id = "VH001"
```

#### **User and Delivery Relationships (Firebase Auth Integration)**
```typescript
// Firebase Auth: Primary user identity
firebase.auth().currentUser.uid = "firebase-uid-abc123"

// Cloud SQL: Business profile linked to Firebase UID
user_profiles.firebase_uid = "firebase-uid-abc123"
drivers.firebase_uid = "firebase-uid-abc123"

// Firestore: Real-time delivery tracking
/deliveries/DL-123 {
  assignment: {
    driverFirebaseUid: "firebase-uid-abc123"
  }
}

// BigQuery: Historical delivery analytics  
deliveries.driver_firebase_uid = "firebase-uid-abc123"
```

## **📋 Schema Summary by Database**

### **BigQuery Schemas**
Detailed in: [`docs/bigquery_schema.md`](./bigquery_schema.md)

**Datasets:**
- `intelligent_dataops_analytics`
  - `iot_telemetry` - Vehicle telemetry data (partitioned by date)
  - `deliveries` - Delivery records and performance
  - `vehicles` - Fleet master data
- `intelligent_dataops_realtime` 
  - `live_vehicle_status` - Current vehicle positions
  - `operational_metrics` - Real-time KPIs

**Key Features:**
- Date partitioning for cost optimization
- Clustering for query performance
- Materialized views for common aggregations
- 90-day automatic data retention

### **Firestore Schemas**
Detailed in: [`docs/firestore-schema.md`](./firestore-schema.md)

**Collections:**
- `/vehicles/{vehicleId}` - Real-time vehicle status
  - `/trips/{tripId}` - Individual trip records
  - `/alerts/{alertId}` - Vehicle alerts and warnings
- `/deliveries/{deliveryId}` - Active delivery tracking
  - `/status_updates/{updateId}` - Status change history
  - `/customer_communications/{messageId}` - Notification log
- `/real_time_tracking/{sessionId}` - Live GPS tracking
  - `/location_updates/{updateId}` - GPS coordinate history
- `/operational_state/` - System-wide operational metrics

**Key Features:**
- Real-time subscriptions for live updates
- Hierarchical data organization
- Offline-first mobile app support
- Security rules for access control

### **Cloud SQL Schemas**
Detailed in: [`docs/cloudsql-schema.md`](./cloudsql-schema.md)

**Core Tables:**
- **User Management**: `users`, `roles`, `departments`
- **Fleet Management**: `drivers`, `vehicle_fleet`, `depots`
- **System Configuration**: `system_configurations`, `notification_templates`
- **External Integration**: `external_systems`, `api_logs`
- **Audit & Compliance**: `audit_trails`

**Key Features:**
- ACID transactions for data integrity
- Complex relationships with foreign keys
- Row-level security for data isolation
- Comprehensive audit trailing

## **🔍 Common Query Patterns**

### **Cross-Database Queries**

#### **Fleet Status Dashboard Query**
```javascript
// 1. Get real-time vehicle positions from Firestore
const vehicleSnapshots = await db.collection('vehicles')
  .where('currentStatus.operational.status', '==', 'active')
  .get();

// 2. Get vehicle specifications from Cloud SQL
const vehicleSpecs = await pool.query(`
  SELECT vehicle_identifier, make, model, max_weight_capacity_kg
  FROM vehicle_fleet 
  WHERE vehicle_identifier IN ($1)
`, [vehicleIds]);

// 3. Get performance analytics from BigQuery
const performanceData = await bigquery.query(`
  SELECT vehicle_id, AVG(speed_kmh) as avg_speed, AVG(fuel_level) as avg_fuel
  FROM \`intelligent_dataops_analytics.iot_telemetry\`
  WHERE DATE(timestamp) = CURRENT_DATE()
    AND vehicle_id IN UNNEST(@vehicleIds)
  GROUP BY vehicle_id
`, {params: {vehicleIds}});
```

#### **Delivery Performance Analysis**
```sql
-- BigQuery: Historical delivery performance
WITH delivery_metrics AS (
  SELECT 
    d.delivery_id,
    d.vehicle_id,
    d.driver_id,
    d.scheduled_delivery_time,
    d.actual_delivery_time,
    DATETIME_DIFF(d.actual_delivery_time, d.scheduled_delivery_time, MINUTE) as delay_minutes
  FROM `intelligent_dataops_analytics.deliveries` d
  WHERE DATE(d.scheduled_delivery_time) >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
    AND d.status = 'delivered'
)
SELECT 
  vehicle_id,
  COUNT(*) as total_deliveries,
  AVG(delay_minutes) as avg_delay_minutes,
  COUNTIF(delay_minutes <= 0) as on_time_deliveries,
  ROUND(COUNTIF(delay_minutes <= 0) * 100.0 / COUNT(*), 2) as on_time_percentage
FROM delivery_metrics
GROUP BY vehicle_id
ORDER BY on_time_percentage DESC;
```

```sql
-- Cloud SQL: Driver performance correlation
SELECT 
  d.driver_id,
  u.first_name || ' ' || u.last_name as driver_name,
  d.total_deliveries,
  d.successful_deliveries,
  d.average_rating,
  d.safety_score
FROM drivers d
JOIN users u ON d.user_id = u.user_id
WHERE d.employment_status = 'active'
ORDER BY d.average_rating DESC, d.safety_score DESC;
```

### **Real-time Event Processing**

#### **Vehicle Location Update Workflow**
```javascript
// 1. Receive telemetry from Pub/Sub via Dataflow
const telemetryData = {
  vehicle_id: 'VH001',
  timestamp: '2025-10-07T10:30:00Z',
  latitude: 41.8781,
  longitude: -87.6298,
  speed_kmh: 65.5,
  fuel_level: 78.3
};

// 2. Update real-time status in Firestore
await db.collection('vehicles').doc('VH001').update({
  'currentStatus.location': {
    latitude: telemetryData.latitude,
    longitude: telemetryData.longitude,
    timestamp: new Date(telemetryData.timestamp)
  },
  'currentStatus.operational.speed': telemetryData.speed_kmh,
  'currentStatus.operational.fuelLevel': telemetryData.fuel_level,
  'currentStatus.operational.lastUpdate': new Date()
});

// 3. Store historical data in BigQuery (via Dataflow)
// This happens automatically through the streaming pipeline

// 4. Check for business rules in Cloud SQL
const alertRules = await pool.query(`
  SELECT rule_name, condition_sql, action_type
  FROM alert_rules 
  WHERE is_active = true
    AND applies_to_vehicle_type = (
      SELECT vehicle_type FROM vehicle_fleet WHERE vehicle_identifier = $1
    )
`, ['VH001']);

// 5. Trigger alerts if conditions are met
if (telemetryData.fuel_level < 20) {
  await triggerLowFuelAlert('VH001', telemetryData.fuel_level);
}
```

## **🚀 Performance Optimization Strategies**

### **BigQuery Optimization**
```sql
-- 1. Use partitioning and clustering
CREATE TABLE `iot_telemetry_optimized` (
  timestamp TIMESTAMP,
  vehicle_id STRING,
  -- other columns
)
PARTITION BY DATE(timestamp)
CLUSTER BY vehicle_id, device_type;

-- 2. Use materialized views for common queries
CREATE MATERIALIZED VIEW `daily_vehicle_summary`
PARTITION BY summary_date
AS
SELECT 
  DATE(timestamp) as summary_date,
  vehicle_id,
  COUNT(*) as reading_count,
  AVG(speed_kmh) as avg_speed
FROM `iot_telemetry`
GROUP BY DATE(timestamp), vehicle_id;

-- 3. Optimize query with proper filtering
SELECT vehicle_id, avg_speed
FROM `daily_vehicle_summary`
WHERE summary_date = '2025-10-07'  -- Partition pruning
  AND vehicle_id = 'VH001';        -- Cluster filtering
```

### **Firestore Optimization**
```javascript
// 1. Use composite indexes for complex queries
// Index: vehicles
// Fields: currentStatus.operational.status (ASC), currentStatus.assignment.currentRouteId (ASC)

// 2. Implement efficient real-time listeners
const unsubscribe = db.collection('vehicles')
  .where('currentStatus.operational.status', '==', 'active')
  .onSnapshot({
    next: (snapshot) => {
      snapshot.docChanges().forEach((change) => {
        if (change.type === 'modified') {
          updateVehicleMarker(change.doc.data());
        }
      });
    },
    error: (error) => console.error('Listener error:', error)
  });

// 3. Use batch writes for efficiency
const batch = db.batch();
updates.forEach((update) => {
  const ref = db.collection('vehicles').doc(update.vehicleId);
  batch.update(ref, update.data);
});
await batch.commit();
```

### **Cloud SQL Optimization**
```sql
-- 1. Use appropriate indexes
CREATE INDEX CONCURRENTLY idx_vehicles_status_active 
ON vehicle_fleet (operational_status) 
WHERE operational_status = 'active';

-- 2. Use connection pooling
-- Configure in application: pool_size=10, max_overflow=20

-- 3. Optimize complex queries with CTEs
WITH active_vehicles AS (
  SELECT vehicle_id, vehicle_identifier, assigned_driver_id
  FROM vehicle_fleet 
  WHERE operational_status = 'active'
),
driver_info AS (
  SELECT d.driver_id, u.first_name, u.last_name
  FROM drivers d
  JOIN users u ON d.user_id = u.user_id
  WHERE d.employment_status = 'active'
)
SELECT 
  av.vehicle_identifier,
  di.first_name || ' ' || di.last_name as driver_name
FROM active_vehicles av
LEFT JOIN driver_info di ON av.assigned_driver_id = di.driver_id;
```

## **🔒 Security & Access Control**

### **Access Control Architecture Overview**

![Access Control Architecture](./Access_Control_Architecture.png)

The platform implements a **comprehensive multi-layered security architecture** with Firebase Authentication as the central identity provider, integrating OAuth providers and custom role-based access control across all database systems.

### **Security Flow Components**

1. **Authentication Layer**
   - OAuth providers (Google, GitHub) for secure login
   - Firebase Authentication & Identity Platform
   - JWT token generation with custom claims
   - Session management and token refresh

2. **Authorization Layer**
   - Firebase Auth SDK with role-based permissions
   - Custom claims for business roles and permissions
   - Backend API/microservices JWT verification
   - Database-specific access control enforcement

3. **Database Security**
   - **BigQuery**: Row-level security with service account permissions
   - **Firestore**: Real-time security rules with Firebase Auth integration
   - **Cloud SQL**: Role-based access policies with Firebase UID references

4. **Monitoring & Compliance**
   - Comprehensive audit logging for all access attempts
   - Real-time monitoring of authorized and unauthorized access
   - Alert system for security violations

### **Complete Security Flow**

```mermaid
sequenceDiagram
    participant User as User Interface
    participant OAuth as OAuth Providers
    participant Firebase as Firebase Auth
    participant Backend as Backend API
    participant BQ as BigQuery
    participant FS as Firestore
    participant SQL as Cloud SQL
    participant Audit as Audit Logs

    User->>OAuth: 1. Login Request
    OAuth->>Firebase: 2. OAuth Token
    Firebase->>Firebase: 3. Verify & Generate JWT
    Firebase->>User: 4. JWT with Custom Claims
    
    User->>Backend: 5. API Request + JWT
    Backend->>Backend: 6. Verify JWT & Extract Claims
    Backend->>Backend: 7. Evaluate Permissions
    
    alt BigQuery Access
        Backend->>BQ: 8a. Query with Service Account
        BQ->>BQ: Row-level Security Check
        BQ->>Backend: Results
    else Firestore Access
        Backend->>FS: 8b. Request with Auth Context
        FS->>FS: Security Rules Evaluation
        FS->>Backend: Real-time Data
    else Cloud SQL Access
        Backend->>SQL: 8c. Query with User Context
        SQL->>SQL: Role-based Access Policy
        SQL->>Backend: Business Data
    end
    
    Backend->>Audit: 9. Log Access Attempt
    Backend->>User: 10. Authorized Response
```

### **Role-Based Access Control (RBAC)**

Based on the architecture diagram, the system implements these access levels:

| Role | Firebase Claims | BigQuery Access | Firestore Access | Cloud SQL Access |
|------|----------------|-----------------|------------------|------------------|
| **Super Admin** | `{role: 'super_admin', permissions: ['*']}` | Full access | Full access | Full access |
| **Fleet Manager** | `{role: 'fleet_manager', dept: 'operations'}` | Fleet analytics | Vehicle/driver data | Fleet management tables |
| **Dispatcher** | `{role: 'dispatcher', permissions: ['delivery.*']}` | Delivery reports | Delivery tracking | Route management |
| **Driver** | `{role: 'driver', vehicle: 'VH001'}` | Own performance | Assigned deliveries | Own profile data |
| **Customer** | `{role: 'customer', customer_id: 'uid'}` | None | Own deliveries | None |

### **Database-Specific Security**

#### **BigQuery Security**
```sql
-- Row-level security based on user context
CREATE ROW ACCESS POLICY fleet_access_policy
ON `iot_telemetry`
GRANT TO ("group:fleet-managers@company.com")
FILTER USING (
  vehicle_id IN (
    SELECT vehicle_id FROM `authorized_vehicles`
    WHERE manager_email = SESSION_USER()
  )
);
```

#### **Firestore Security Rules**
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Vehicles - read for authenticated users, write for system
    match /vehicles/{vehicleId} {
      allow read: if request.auth != null;
      allow write: if request.auth.token.role in ['system', 'admin'];
    }
    
    // Deliveries - customers see only their deliveries
    match /deliveries/{deliveryId} {
      allow read: if request.auth != null && (
        request.auth.token.role in ['admin', 'dispatcher'] ||
        resource.data.customerId == request.auth.uid
      );
    }
  }
}
```

#### **Cloud SQL Security**
```sql
-- Row-level security
ALTER TABLE vehicle_fleet ENABLE ROW LEVEL SECURITY;

CREATE POLICY vehicle_access_policy ON vehicle_fleet
FOR ALL TO authenticated_users
USING (
  current_user_role() IN ('super_admin', 'fleet_manager') OR
  assigned_driver_id = current_user_driver_id()
);

-- Encrypt sensitive data
INSERT INTO system_configurations (config_key, config_value, is_sensitive)
VALUES ('api_secret_key', encrypt('secret_value', 'encryption_key'), true);
```

## **📈 Monitoring & Observability**

### **Database Health Monitoring**
```sql
-- BigQuery: Query performance monitoring
SELECT 
  user_email,
  job_id,
  total_bytes_processed / POWER(1024, 3) as gb_processed,
  total_slot_ms / (1000 * 60) as slot_minutes,
  ROUND(total_bytes_processed / POWER(1024, 4) * 5.00, 4) as cost_usd
FROM `region-us-central1.INFORMATION_SCHEMA.JOBS_BY_PROJECT`
WHERE creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)
ORDER BY total_bytes_processed DESC;

-- Cloud SQL: Connection monitoring
SELECT 
    datname,
    numbackends,
    xact_commit,
    xact_rollback,
    blks_read,
    blks_hit,
    temp_files,
    deadlocks
FROM pg_stat_database 
WHERE datname = 'intelligent_dataops';
```

### **Cross-Database Consistency Checks**
```javascript
// Verify data consistency across systems
async function validateDataConsistency() {
  // 1. Get vehicle count from each system
  const sqlVehicleCount = await pool.query('SELECT COUNT(*) FROM vehicle_fleet WHERE is_active = true');
  const firestoreVehicleCount = await db.collection('vehicles').where('metadata.isActive', '==', true).get();
  
  // 2. Check for orphaned records
  const bqOrphans = await bigquery.query(`
    SELECT vehicle_id 
    FROM \`iot_telemetry\`
    WHERE vehicle_id NOT IN (
      SELECT vehicle_identifier FROM \`vehicle_master_data\`
    )
    LIMIT 10
  `);
  
  // 3. Report inconsistencies
  if (sqlVehicleCount.rows[0].count !== firestoreVehicleCount.size) {
    console.warn('Vehicle count mismatch between SQL and Firestore');
  }
}
```

## **🔧 Maintenance & Operations**

### **Backup Strategies**
- **BigQuery**: Automatic snapshots, cross-region replication
- **Firestore**: Automatic daily backups, point-in-time recovery
- **Cloud SQL**: Automated daily backups, transaction log backups

### **Data Lifecycle Management**
- **BigQuery**: 90-day partition expiration, archive to Cloud Storage
- **Firestore**: TTL on temporary collections, manual cleanup for historical data
- **Cloud SQL**: Regular maintenance windows, index optimization

### **Disaster Recovery**
- **RTO (Recovery Time Objective)**: 4 hours
- **RPO (Recovery Point Objective)**: 1 hour
- **Cross-region failover**: Automated for Cloud SQL, manual for BigQuery/Firestore

This database architecture provides a robust, scalable, and secure foundation for the Intelligent DataOps Platform, with each database optimized for its specific role in the overall system.