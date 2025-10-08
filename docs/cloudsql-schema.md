# Cloud SQL Schema & Operational Database

## **🎯 Purpose**

Cloud SQL serves as the **operational relational database** for the Intelligent DataOps Platform. It manages business user profiles, system configurations, business logic, and transactional data that requires ACID compliance, complex relationships, and SQL-based operations.

**Note**: Authentication is handled by **Firebase Authentication**. Cloud SQL stores only business-specific user metadata and relationships.

## **🏗️ Database Architecture**

```
Authentication Layer: Firebase Authentication (Separate Service)
├── User Registration & Login
├── Password Management & Reset  
├── OAuth Providers (Google, Apple, etc.)
├── Session Management & JWT Tokens
└── Multi-Factor Authentication

Cloud SQL PostgreSQL Instance: intelligent-dataops-operational
├── Business User Profiles (linked to Firebase UIDs)
├── System Configuration & Settings  
├── Business Logic & Rules
├── Integration & External Systems
└── Operational Transactions
```

**Instance Configuration:**
- **Engine**: PostgreSQL 15
- **Instance**: db-f1-micro (development), db-n1-standard-2 (production)
- **Storage**: 20GB SSD (auto-scaling enabled)
- **Backups**: Daily automated backups with 7-day retention
- **High Availability**: Regional persistent disks with failover

## **👥 Firebase Authentication Integration**

### **Authentication Flow**
```typescript
// Firebase raw authentication data
interface FirebaseUser {
  uid: string;                    // Firebase UID (primary identifier)
  email: string;                 // Managed by Firebase
  displayName: string;           // Managed by Firebase
  photoURL: string;              // Managed by Firebase
  emailVerified: boolean;        // Managed by Firebase
  disabled: boolean;             // Managed by Firebase
  customClaims?: Record<string, any>; // Raw Firebase claims (generic)
}

// Business-focused user interface for our application
interface AuthenticatedUser {
  firebaseUid: string;
  email: string;
  displayName: string;
  emailVerified: boolean;
  
  // Clear business-specific properties
  businessRole: UserRole;
  permissions: Permission[];
  organizationalAccess: OrganizationalAccess;
  
  // Keep reference to raw Firebase data for debugging
  _rawFirebaseData?: FirebaseUser;
}

interface OrganizationalAccess {
  department?: string;
  fleetAssignment?: string[];
  vehicleAccess?: string[];
  routeAccess?: string[];
  managerId?: string;
  costCenter?: string;
}

type UserRole = 'super_admin' | 'fleet_manager' | 'dispatcher' | 'driver' | 'customer' | 'analyst';
type Permission = 'fleet.read' | 'fleet.write' | 'delivery.read' | 'delivery.write' | 'analytics.read' | 'system.admin';
```

### **user_profiles Table** (Business Metadata Only)
```sql
CREATE TABLE user_profiles (
    profile_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    firebase_uid VARCHAR(128) UNIQUE NOT NULL, -- Links to Firebase Auth UID
    
    -- Business Information (not handled by Firebase)
    employee_id VARCHAR(20) UNIQUE,
    job_title VARCHAR(100),
    hire_date DATE,
    salary_grade VARCHAR(10),
    
    -- Business Relationships
    role_id UUID NOT NULL REFERENCES roles(role_id),
    department_id UUID REFERENCES departments(department_id),
    manager_firebase_uid VARCHAR(128) REFERENCES user_profiles(firebase_uid),
    
    -- Business Status (separate from Firebase account status)
    employment_status employment_status_enum DEFAULT 'active',
    work_location VARCHAR(100),
    cost_center_code VARCHAR(20),
    
    -- Business Contact (supplementary to Firebase)
    work_phone VARCHAR(20),
    emergency_contact_name VARCHAR(100),
    emergency_contact_phone VARCHAR(20),
    
    -- Business Preferences
    timezone VARCHAR(50) DEFAULT 'America/Chicago',
    language_preference VARCHAR(5) DEFAULT 'en-US',
    notification_preferences JSONB DEFAULT '{}',
    
    -- Audit
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by_firebase_uid VARCHAR(128),
    updated_by_firebase_uid VARCHAR(128)
);

-- Enums
CREATE TYPE employment_status_enum AS ENUM ('active', 'inactive', 'on_leave', 'terminated', 'contractor');

-- Indexes
CREATE INDEX idx_user_profiles_firebase_uid ON user_profiles(firebase_uid);
CREATE INDEX idx_user_profiles_employee_id ON user_profiles(employee_id);
CREATE INDEX idx_user_profiles_role_id ON user_profiles(role_id);
CREATE INDEX idx_user_profiles_department_id ON user_profiles(department_id);
CREATE INDEX idx_user_profiles_employment_status ON user_profiles(employment_status);
CREATE INDEX idx_user_profiles_manager ON user_profiles(manager_firebase_uid);

-- Constraint to ensure Firebase UID format
ALTER TABLE user_profiles ADD CONSTRAINT chk_firebase_uid_format 
    CHECK (LENGTH(firebase_uid) >= 20 AND firebase_uid ~ '^[a-zA-Z0-9]+$');
```

### **Firebase Auth + Cloud SQL Integration Patterns**
```typescript
// 1. User Registration Flow with Business Role Assignment
async function createUserWithBusinessProfile(registrationData: RegistrationData): Promise<AuthenticatedUser> {
  // Step 1: Create Firebase user account
  const firebaseUser = await admin.auth().createUser({
    email: registrationData.email,
    displayName: `${registrationData.firstName} ${registrationData.lastName}`,
    disabled: false
  });
  
  // Step 2: Store business metadata in Cloud SQL
  const businessProfile = await pool.query(`
    INSERT INTO user_profiles (
      firebase_uid, employee_id, job_title, hire_date, 
      role_id, department_id, employment_status
    ) VALUES ($1, $2, $3, $4, $5, $6, $7)
    RETURNING profile_id
  `, [firebaseUser.uid, registrationData.employeeId, registrationData.jobTitle, 
      registrationData.hireDate, registrationData.roleId, registrationData.departmentId, 'active']);
  
  // Step 3: Set business role and permissions in Firebase for authorization
  const businessClaims = {
    role: registrationData.businessRole,
    department: registrationData.departmentCode,
    permissions: registrationData.permissions,
    fleetAssignment: registrationData.fleetAssignment,
    vehicleAccess: registrationData.vehicleAccess
  };
  
  await admin.auth().setCustomUserClaims(firebaseUser.uid, businessClaims);
  
  return mapToAuthenticatedUser(firebaseUser, businessClaims, businessProfile.rows[0]);
}

// 2. User Authentication & Complete Profile Retrieval
async function authenticateAndLoadBusinessProfile(firebaseUid: string): Promise<AuthenticatedUser> {
  // Get Firebase authentication data
  const firebaseUser = await admin.auth().getUser(firebaseUid);
  
  // Get complete business profile from Cloud SQL
  const businessData = await pool.query(`
    SELECT 
      up.*,
      r.role_name,
      r.permissions,
      d.department_name,
      d.department_code
    FROM user_profiles up
    JOIN roles r ON up.role_id = r.role_id
    LEFT JOIN departments d ON up.department_id = d.department_id
    WHERE up.firebase_uid = $1 AND up.employment_status = 'active'
  `, [firebaseUid]);
  
  if (businessData.rows.length === 0) {
    throw new Error('Business profile not found or inactive');
  }
  
  return mapToAuthenticatedUser(firebaseUser, firebaseUser.customClaims, businessData.rows[0]);
}

// 3. Mapping Firebase data to business-focused interface
function mapToAuthenticatedUser(
  firebaseUser: admin.auth.UserRecord, 
  businessClaims: any, 
  businessProfile: any
): AuthenticatedUser {
  return {
    firebaseUid: firebaseUser.uid,
    email: firebaseUser.email!,
    displayName: firebaseUser.displayName || '',
    emailVerified: firebaseUser.emailVerified,
    
    businessRole: businessClaims?.role as UserRole,
    permissions: businessClaims?.permissions || [],
    organizationalAccess: {
      department: businessProfile.department_name,
      fleetAssignment: businessClaims?.fleetAssignment || [],
      vehicleAccess: businessClaims?.vehicleAccess || [],
      managerId: businessProfile.manager_firebase_uid,
      costCenter: businessProfile.cost_center_code
    },
    
    _rawFirebaseData: firebaseUser
  };
}

interface RegistrationData {
  email: string;
  firstName: string;
  lastName: string;
  employeeId: string;
  jobTitle: string;
  hireDate: string;
  roleId: string;
  departmentId: string;
  businessRole: UserRole;
  departmentCode: string;
  permissions: Permission[];
  fleetAssignment?: string[];
  vehicleAccess?: string[];
}
```

### **💰 Cost Benefits Analysis**

**Firebase Authentication vs Cloud SQL Authentication:**

| Factor | Firebase Auth | Cloud SQL Auth | Savings |
|--------|---------------|----------------|---------|
| **Monthly Fixed Cost** | $0 (pay-per-use) | $25-50 (db-f1-micro) | $25-50/month |
| **Authentication Requests** | $0.006/1000 requests | Included in instance | Variable |
| **Development Time** | ~2 weeks less | ~2 weeks more | $4,000-8,000 |
| **Security Features** | Built-in (MFA, OAuth) | Custom implementation | $5,000-10,000 |
| **Maintenance** | Managed by Google | Manual maintenance | $1,000-2,000/month |

**Break-even Analysis:**
- **Small Scale** (<10,000 auth/month): Firebase saves $25-50/month immediately
- **Medium Scale** (10k-100k auth/month): Firebase saves $20-45/month + dev costs
- **Large Scale** (>100k auth/month): Firebase costs ~$60/month vs $50 fixed Cloud SQL

**Recommendation**: Use Firebase Auth for authentication, Cloud SQL for business data.

### **roles Table**
```sql
CREATE TABLE roles (
    role_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role_name VARCHAR(50) UNIQUE NOT NULL,
    display_name VARCHAR(100) NOT NULL,
    description TEXT,
    
    -- Hierarchy
    parent_role_id UUID REFERENCES roles(role_id),
    role_level INTEGER NOT NULL DEFAULT 0,
    
    -- Permissions
    permissions JSONB NOT NULL DEFAULT '[]',
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    is_system_role BOOLEAN DEFAULT FALSE,
    
    -- Audit
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Example roles data
INSERT INTO roles (role_name, display_name, description, permissions) VALUES 
('super_admin', 'Super Administrator', 'Full system access', 
 '["system.*", "user.*", "fleet.*", "delivery.*", "analytics.*"]'),
 
('fleet_manager', 'Fleet Manager', 'Manage vehicles and drivers',
 '["fleet.read", "fleet.write", "vehicle.read", "vehicle.write", "driver.read", "driver.write"]'),
 
('dispatcher', 'Dispatcher', 'Manage deliveries and routes',
 '["delivery.read", "delivery.write", "route.read", "route.write", "vehicle.read"]'),
 
('driver', 'Driver', 'Mobile app access for deliveries',
 '["delivery.read_assigned", "delivery.update_status", "vehicle.read_assigned", "location.write"]'),
 
('customer', 'Customer', 'Track deliveries and view status',
 '["delivery.read_own", "tracking.read_own"]'),
 
('analyst', 'Data Analyst', 'Read-only access to analytics',
 '["analytics.read", "reports.read", "dashboard.read"]');
```

### **departments Table**
```sql
CREATE TABLE departments (
    department_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    department_name VARCHAR(100) NOT NULL,
    department_code VARCHAR(10) UNIQUE NOT NULL,
    description TEXT,
    
    -- Hierarchy
    parent_department_id UUID REFERENCES departments(department_id),
    department_path TEXT, -- Materialized path for hierarchy queries
    
    -- Manager
    manager_firebase_uid VARCHAR(128) REFERENCES user_profiles(firebase_uid),
    
    -- Settings
    budget_allocation DECIMAL(15,2),
    cost_center_code VARCHAR(20),
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Example departments
INSERT INTO departments (department_name, department_code, description) VALUES 
('Operations', 'OPS', 'Fleet and delivery operations'),
('Technology', 'TECH', 'IT and software development'),
('Customer Service', 'CS', 'Customer support and communications'),
('Analytics', 'ANALYTICS', 'Data analysis and business intelligence');
```

## **🚛 Fleet Management Schema**

### **drivers Table**
```sql
CREATE TABLE drivers (
    driver_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    firebase_uid VARCHAR(128) UNIQUE NOT NULL REFERENCES user_profiles(firebase_uid),
    employee_id VARCHAR(20) UNIQUE NOT NULL,
    
    -- License Information
    license_number VARCHAR(50) UNIQUE NOT NULL,
    license_class VARCHAR(10) NOT NULL,
    license_expiry_date DATE NOT NULL,
    license_state VARCHAR(2) NOT NULL,
    
    -- Certification
    cdl_endorsed BOOLEAN DEFAULT FALSE,
    hazmat_certified BOOLEAN DEFAULT FALSE,
    certification_expiry DATE,
    
    -- Work Information
    hire_date DATE NOT NULL,
    employment_status employment_status_enum DEFAULT 'active',
    pay_rate_per_hour DECIMAL(8,2),
    
    -- Performance Metrics
    total_deliveries INTEGER DEFAULT 0,
    successful_deliveries INTEGER DEFAULT 0,
    average_rating DECIMAL(3,2) DEFAULT 0.00,
    safety_score DECIMAL(5,2) DEFAULT 100.00,
    
    -- Contact & Emergency
    emergency_contact_name VARCHAR(100),
    emergency_contact_phone VARCHAR(20),
    emergency_contact_relationship VARCHAR(50),
    
    -- Status
    is_available BOOLEAN DEFAULT TRUE,
    current_vehicle_id UUID REFERENCES vehicle_fleet(vehicle_id),
    
    -- Audit
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TYPE employment_status_enum AS ENUM ('active', 'inactive', 'on_leave', 'terminated');

-- Indexes
CREATE INDEX idx_drivers_firebase_uid ON drivers(firebase_uid);
CREATE INDEX idx_drivers_employment_status ON drivers(employment_status);
CREATE INDEX idx_drivers_license_expiry ON drivers(license_expiry_date);
CREATE INDEX idx_drivers_current_vehicle ON drivers(current_vehicle_id);
```

### **vehicle_fleet Table**
```sql
CREATE TABLE vehicle_fleet (
    vehicle_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vehicle_identifier VARCHAR(20) UNIQUE NOT NULL, -- VH001, VH002, etc.
    
    -- Basic Information
    make VARCHAR(50) NOT NULL,
    model VARCHAR(50) NOT NULL,
    year INTEGER NOT NULL,
    color VARCHAR(30),
    license_plate VARCHAR(20) UNIQUE NOT NULL,
    vin VARCHAR(17) UNIQUE NOT NULL,
    
    -- Classification
    vehicle_type vehicle_type_enum NOT NULL,
    fleet_category VARCHAR(50) DEFAULT 'standard',
    
    -- Specifications
    max_weight_capacity_kg INTEGER NOT NULL,
    max_volume_capacity_m3 DECIMAL(8,2) NOT NULL,
    fuel_tank_capacity_liters INTEGER NOT NULL,
    fuel_type fuel_type_enum DEFAULT 'gasoline',
    
    -- Operational Status
    operational_status operational_status_enum DEFAULT 'available',
    current_odometer_km INTEGER DEFAULT 0,
    
    -- Assignment
    assigned_driver_id UUID REFERENCES drivers(driver_id),
    home_depot_id UUID REFERENCES depots(depot_id),
    
    -- Maintenance
    last_maintenance_date DATE,
    next_maintenance_due_km INTEGER,
    maintenance_interval_km INTEGER DEFAULT 10000,
    
    -- Insurance & Registration
    insurance_policy_number VARCHAR(50),
    insurance_expiry_date DATE NOT NULL,
    registration_expiry_date DATE NOT NULL,
    
    -- Financial
    purchase_date DATE,
    purchase_price DECIMAL(12,2),
    current_book_value DECIMAL(12,2),
    monthly_depreciation DECIMAL(8,2),
    
    -- IoT Device Integration
    primary_device_id VARCHAR(50), -- Links to IoT telemetry
    secondary_device_id VARCHAR(50),
    device_last_contact TIMESTAMP WITH TIME ZONE,
    
    -- Audit
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_active BOOLEAN DEFAULT TRUE
);

-- Enums
CREATE TYPE vehicle_type_enum AS ENUM ('truck', 'van', 'pickup', 'motorcycle', 'bicycle');
CREATE TYPE fuel_type_enum AS ENUM ('gasoline', 'diesel', 'electric', 'hybrid', 'propane');
CREATE TYPE operational_status_enum AS ENUM ('available', 'in_use', 'maintenance', 'out_of_service', 'retired');

-- Indexes
CREATE INDEX idx_vehicle_fleet_identifier ON vehicle_fleet(vehicle_identifier);
CREATE INDEX idx_vehicle_fleet_status ON vehicle_fleet(operational_status);
CREATE INDEX idx_vehicle_fleet_driver ON vehicle_fleet(assigned_driver_id);
CREATE INDEX idx_vehicle_fleet_type ON vehicle_fleet(vehicle_type);
```

### **depots Table**
```sql
CREATE TABLE depots (
    depot_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    depot_code VARCHAR(10) UNIQUE NOT NULL,
    depot_name VARCHAR(100) NOT NULL,
    
    -- Location
    address JSONB NOT NULL, -- {street, city, state, postal_code, country}
    coordinates POINT NOT NULL, -- PostGIS point (longitude, latitude)
    timezone VARCHAR(50) NOT NULL DEFAULT 'America/Chicago',
    
    -- Capacity
    max_vehicle_capacity INTEGER NOT NULL DEFAULT 50,
    current_vehicle_count INTEGER DEFAULT 0,
    
    -- Operational Hours
    operating_hours JSONB NOT NULL DEFAULT '{}', -- {monday: {open: "06:00", close: "22:00"}, ...}
    is_24_hour BOOLEAN DEFAULT FALSE,
    
    -- Manager
    manager_firebase_uid VARCHAR(128) REFERENCES user_profiles(firebase_uid),
    
    -- Contact Information
    phone_number VARCHAR(20),
    email_address VARCHAR(255),
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Spatial index for location-based queries
CREATE INDEX idx_depots_coordinates ON depots USING GIST (coordinates);
CREATE INDEX idx_depots_active ON depots(is_active);
```

## **📋 Configuration & Settings Schema**

### **system_configurations Table**
```sql
CREATE TABLE system_configurations (
    config_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    config_key VARCHAR(100) UNIQUE NOT NULL,
    config_value TEXT NOT NULL,
    config_type config_type_enum DEFAULT 'string',
    
    -- Organization
    category VARCHAR(50) NOT NULL,
    subcategory VARCHAR(50),
    
    -- Metadata
    description TEXT,
    is_sensitive BOOLEAN DEFAULT FALSE,
    is_user_configurable BOOLEAN DEFAULT TRUE,
    requires_restart BOOLEAN DEFAULT FALSE,
    
    -- Validation
    validation_rules JSONB, -- JSON schema for value validation
    default_value TEXT,
    
    -- Environment
    environment VARCHAR(20) DEFAULT 'all', -- 'development', 'staging', 'production', 'all'
    
    -- Audit
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_by_firebase_uid VARCHAR(128)
);

CREATE TYPE config_type_enum AS ENUM ('string', 'integer', 'decimal', 'boolean', 'json', 'array');

-- Example configurations
INSERT INTO system_configurations (config_key, config_value, config_type, category, description) VALUES 
-- Operational Settings
('default_delivery_timeout_hours', '24', 'integer', 'delivery', 'Default timeout for delivery attempts'),
('max_delivery_attempts', '3', 'integer', 'delivery', 'Maximum number of delivery attempts'),
('driver_check_in_interval_minutes', '15', 'integer', 'fleet', 'How often drivers must check in'),

-- Notification Settings  
('sms_notifications_enabled', 'true', 'boolean', 'notifications', 'Enable SMS notifications'),
('email_notifications_enabled', 'true', 'boolean', 'notifications', 'Enable email notifications'),
('notification_retry_attempts', '3', 'integer', 'notifications', 'Number of notification retry attempts'),

-- AI/ML Settings
('anomaly_detection_threshold', '0.8', 'decimal', 'ml', 'Threshold for anomaly detection alerts'),
('route_optimization_enabled', 'true', 'boolean', 'ml', 'Enable AI-powered route optimization'),
('predictive_eta_model_version', 'v2.1.0', 'string', 'ml', 'Current ETA prediction model version'),

-- Integration Settings
('google_maps_api_quota_daily', '10000', 'integer', 'integrations', 'Daily quota for Google Maps API calls'),
('weather_service_refresh_minutes', '30', 'integer', 'integrations', 'Weather data refresh interval'),
('external_api_timeout_seconds', '30', 'integer', 'integrations', 'Timeout for external API calls');

-- Indexes
CREATE INDEX idx_system_configurations_key ON system_configurations(config_key);
CREATE INDEX idx_system_configurations_category ON system_configurations(category);
CREATE INDEX idx_system_configurations_environment ON system_configurations(environment);
```

### **notification_templates Table**
```sql
CREATE TABLE notification_templates (
    template_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    template_name VARCHAR(100) UNIQUE NOT NULL,
    template_type notification_type_enum NOT NULL,
    
    -- Content
    subject VARCHAR(200), -- For email templates
    message_template TEXT NOT NULL,
    html_template TEXT, -- For email templates
    
    -- Delivery Channels
    channels notification_channel_enum[] DEFAULT ARRAY['email'], -- Array of supported channels
    
    -- Variables
    template_variables JSONB DEFAULT '[]', -- List of available template variables
    
    -- Localization
    language_code VARCHAR(5) DEFAULT 'en-US',
    
    -- Conditions
    trigger_conditions JSONB, -- When to use this template
    priority notification_priority_enum DEFAULT 'normal',
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    is_system_template BOOLEAN DEFAULT FALSE,
    
    -- Audit
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_by_firebase_uid VARCHAR(128)
);

-- Enums
CREATE TYPE notification_type_enum AS ENUM ('delivery_update', 'delivery_exception', 'driver_alert', 'system_alert', 'marketing');
CREATE TYPE notification_channel_enum AS ENUM ('email', 'sms', 'push', 'in_app', 'webhook');
CREATE TYPE notification_priority_enum AS ENUM ('low', 'normal', 'high', 'urgent');

-- Example templates
INSERT INTO notification_templates (template_name, template_type, subject, message_template, template_variables) VALUES 
('delivery_out_for_delivery', 'delivery_update', 
 'Your package is out for delivery', 
 'Hi {{customer_name}}, your package {{tracking_number}} is out for delivery and should arrive by {{estimated_delivery_time}}. Track your package: {{tracking_url}}',
 '["customer_name", "tracking_number", "estimated_delivery_time", "tracking_url"]'),
 
('delivery_delayed', 'delivery_exception',
 'Delivery Update - Slight Delay Expected',
 'Hi {{customer_name}}, your delivery {{tracking_number}} is experiencing a slight delay. New estimated delivery time: {{new_estimated_time}}. Reason: {{delay_reason}}',
 '["customer_name", "tracking_number", "new_estimated_time", "delay_reason"]');
```

## **🔗 External Integration Schema**

### **external_systems Table**
```sql
CREATE TABLE external_systems (
    system_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    system_name VARCHAR(100) UNIQUE NOT NULL,
    system_type external_system_type_enum NOT NULL,
    
    -- Connection Details
    base_url TEXT,
    api_version VARCHAR(20),
    authentication_type auth_type_enum DEFAULT 'api_key',
    
    -- Credentials (encrypted)
    api_key_encrypted TEXT,
    api_secret_encrypted TEXT,
    oauth_config JSONB,
    
    -- Rate Limiting
    rate_limit_per_minute INTEGER DEFAULT 60,
    rate_limit_per_day INTEGER DEFAULT 10000,
    current_usage_minute INTEGER DEFAULT 0,
    current_usage_day INTEGER DEFAULT 0,
    
    -- Health Monitoring
    is_active BOOLEAN DEFAULT TRUE,
    last_successful_call TIMESTAMP WITH TIME ZONE,
    last_error_at TIMESTAMP WITH TIME ZONE,
    consecutive_failures INTEGER DEFAULT 0,
    health_status health_status_enum DEFAULT 'unknown',
    
    -- Configuration
    timeout_seconds INTEGER DEFAULT 30,
    retry_attempts INTEGER DEFAULT 3,
    circuit_breaker_enabled BOOLEAN DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enums
CREATE TYPE external_system_type_enum AS ENUM ('shipping_carrier', 'payment_processor', 'mapping_service', 'weather_service', 'customer_system', 'inventory_system');
CREATE TYPE auth_type_enum AS ENUM ('api_key', 'oauth2', 'basic_auth', 'bearer_token', 'custom');
CREATE TYPE health_status_enum AS ENUM ('healthy', 'degraded', 'unhealthy', 'unknown');

-- Indexes
CREATE INDEX idx_external_systems_type ON external_systems(system_type);
CREATE INDEX idx_external_systems_health ON external_systems(health_status);
CREATE INDEX idx_external_systems_active ON external_systems(is_active);
```

### **api_logs Table**
```sql
CREATE TABLE api_logs (
    log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    system_id UUID REFERENCES external_systems(system_id),
    
    -- Request Details
    endpoint TEXT NOT NULL,
    http_method VARCHAR(10) NOT NULL,
    request_headers JSONB,
    request_body TEXT,
    
    -- Response Details
    response_status_code INTEGER,
    response_headers JSONB,
    response_body TEXT,
    response_time_ms INTEGER,
    
    -- Context
    firebase_uid VARCHAR(128) REFERENCES user_profiles(firebase_uid),
    correlation_id UUID, -- For tracing across systems
    operation_type VARCHAR(50),
    
    -- Result
    success BOOLEAN,
    error_message TEXT,
    error_code VARCHAR(50),
    
    -- Timestamp
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for performance and monitoring
CREATE INDEX idx_api_logs_system_id ON api_logs(system_id);
CREATE INDEX idx_api_logs_created_at ON api_logs(created_at DESC);
CREATE INDEX idx_api_logs_success ON api_logs(success);
CREATE INDEX idx_api_logs_correlation_id ON api_logs(correlation_id);

-- Partitioning by month for better performance
CREATE TABLE api_logs_template () INHERITS (api_logs);
-- Monthly partitions would be created automatically
```

## **📊 Audit & Compliance Schema**

### **audit_trails Table**
```sql
CREATE TABLE audit_trails (
    audit_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Actor Information
    firebase_uid VARCHAR(128) REFERENCES user_profiles(firebase_uid),
    session_id VARCHAR(255),
    ip_address INET,
    user_agent TEXT,
    
    -- Action Details
    action_type audit_action_enum NOT NULL,
    resource_type VARCHAR(50) NOT NULL,
    resource_id VARCHAR(255) NOT NULL,
    
    -- Changes
    old_values JSONB,
    new_values JSONB,
    changed_fields TEXT[],
    
    -- Context
    operation_description TEXT,
    business_context VARCHAR(100),
    correlation_id UUID,
    
    -- Result
    success BOOLEAN NOT NULL DEFAULT TRUE,
    error_message TEXT,
    
    -- Metadata
    request_id VARCHAR(255),
    api_endpoint TEXT,
    processing_time_ms INTEGER,
    
    -- Timestamp
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TYPE audit_action_enum AS ENUM ('create', 'read', 'update', 'delete', 'login', 'logout', 'permission_change', 'system_action');

-- Indexes for audit queries
CREATE INDEX idx_audit_trails_user_id ON audit_trails(user_id);
CREATE INDEX idx_audit_trails_created_at ON audit_trails(created_at DESC);
CREATE INDEX idx_audit_trails_resource ON audit_trails(resource_type, resource_id);
CREATE INDEX idx_audit_trails_action_type ON audit_trails(action_type);

-- Partitioning by quarter for long-term retention
-- (Implementation would include automatic partition management)
```

## **⚡ Performance Optimization**

### **Connection Pooling Configuration**
```sql
-- Configure connection pooling for high throughput
ALTER SYSTEM SET max_connections = 200;
ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_statements';

-- Enable query performance tracking
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Optimize for read-heavy workloads
ALTER SYSTEM SET effective_cache_size = '1GB';
ALTER SYSTEM SET shared_buffers = '256MB';
ALTER SYSTEM SET work_mem = '4MB';
```

### **Materialized Views for Analytics**
```sql
-- Fleet utilization summary
CREATE MATERIALIZED VIEW fleet_utilization_summary AS
SELECT 
    DATE(created_at) as report_date,
    COUNT(*) as total_vehicles,
    COUNT(*) FILTER (WHERE operational_status = 'in_use') as vehicles_in_use,
    COUNT(*) FILTER (WHERE operational_status = 'available') as vehicles_available,
    COUNT(*) FILTER (WHERE operational_status = 'maintenance') as vehicles_maintenance,
    ROUND(
        COUNT(*) FILTER (WHERE operational_status = 'in_use')::numeric / 
        COUNT(*)::numeric * 100, 2
    ) as utilization_percentage
FROM vehicle_fleet 
WHERE is_active = TRUE
GROUP BY DATE(created_at);

-- Refresh schedule
CREATE OR REPLACE FUNCTION refresh_fleet_utilization_summary()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY fleet_utilization_summary;
END;
$$ LANGUAGE plpgsql;

-- Automated refresh via pg_cron (if available)
-- SELECT cron.schedule('refresh-fleet-summary', '0 6 * * *', 'SELECT refresh_fleet_utilization_summary();');
```

### **Query Optimization Examples**
```sql
-- Efficient driver lookup with status
SELECT 
    d.driver_id,
    u.first_name,
    u.last_name,
    d.employment_status,
    vf.vehicle_identifier
FROM drivers d
JOIN users u ON d.user_id = u.user_id
LEFT JOIN vehicle_fleet vf ON d.current_vehicle_id = vf.vehicle_id
WHERE d.employment_status = 'active'
    AND d.is_available = TRUE
ORDER BY u.last_name, u.first_name;

-- Complex configuration query with defaults
WITH config_hierarchy AS (
    SELECT 
        config_key,
        config_value,
        CASE 
            WHEN environment = 'production' THEN 1
            WHEN environment = 'staging' THEN 2
            WHEN environment = 'development' THEN 3
            ELSE 4
        END as priority
    FROM system_configurations
    WHERE environment IN ('production', 'staging', 'development', 'all')
)
SELECT 
    config_key,
    config_value
FROM config_hierarchy
WHERE (config_key, priority) IN (
    SELECT config_key, MIN(priority)
    FROM config_hierarchy
    GROUP BY config_key
);
```

## **🔒 Security Features**

### **Row Level Security (RLS)**
```sql
-- Enable RLS on sensitive tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Users can only see their own data (except admins)
CREATE POLICY user_isolation_policy ON users
    FOR ALL
    TO authenticated_users
    USING (
        user_id = current_user_id() 
        OR current_user_role() = 'super_admin'
        OR current_user_role() = 'admin'
    );

-- Drivers can only see their assigned vehicles
ALTER TABLE vehicle_fleet ENABLE ROW LEVEL SECURITY;

CREATE POLICY driver_vehicle_access ON vehicle_fleet
    FOR SELECT
    TO authenticated_users
    USING (
        current_user_role() IN ('super_admin', 'fleet_manager', 'dispatcher')
        OR assigned_driver_id = current_driver_id()
    );
```

### **Data Encryption**
```sql
-- Encrypt sensitive configuration values
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Function to encrypt sensitive config values
CREATE OR REPLACE FUNCTION encrypt_config_value(value TEXT, is_sensitive BOOLEAN)
RETURNS TEXT AS $$
BEGIN
    IF is_sensitive THEN
        RETURN encode(encrypt(value::bytea, 'config_encryption_key', 'aes'), 'base64');
    ELSE
        RETURN value;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Function to decrypt sensitive config values  
CREATE OR REPLACE FUNCTION decrypt_config_value(encrypted_value TEXT, is_sensitive BOOLEAN)
RETURNS TEXT AS $$
BEGIN
    IF is_sensitive THEN
        RETURN convert_from(decrypt(decode(encrypted_value, 'base64'), 'config_encryption_key', 'aes'), 'UTF8');
    ELSE
        RETURN encrypted_value;
    END IF;
END;
$$ LANGUAGE plpgsql;
```

This Cloud SQL schema provides the **operational foundation** for the Intelligent DataOps Platform, handling user management, system configuration, fleet operations, and maintaining data integrity across all transactional operations.