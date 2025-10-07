# Firestore Schema & Real-time Data Store

## **🎯 Purpose**

Firestore serves as the **real-time operational data store** for the Intelligent DataOps Platform. It provides sub-second read/write capabilities for live vehicle tracking, active delivery status, real-time notifications, and operational dashboards that require instant updates.

## **🔄 Real-time Architecture**

```
Dataflow Pipeline ──→ Firestore Collections ──→ Real-time Subscriptions
     │                      │                         │
     └── BigQuery ←─────────┘                         └──→ Frontend Dashboard
         (Analytics)                                       (Live Updates)
```

## **📄 Collection Structure**

### **Core Collections Hierarchy**
```
/vehicles/{vehicleId}
├── /trips/{tripId}
├── /maintenance/{recordId}
└── /alerts/{alertId}

/deliveries/{deliveryId}
├── /status_updates/{updateId}
├── /customer_communications/{messageId}
└── /exceptions/{exceptionId}

/real_time_tracking/{sessionId}
├── location_updates (subcollection)
└── performance_metrics (subcollection)

/operational_state/
├── fleet_summary (document)
├── active_routes (document)
└── system_health (document)
```

## **🚛 Vehicle Collections**

### **vehicles Collection**
**Path**: `/vehicles/{vehicleId}`

```typescript
interface VehicleDocument {
  // Identity
  vehicleId: string;
  fleetId: string;
  licensePlate: string;
  
  // Current Status (Real-time Updates)
  currentStatus: {
    location: {
      latitude: number;
      longitude: number;
      accuracy: number;
      timestamp: FirebaseFirestore.Timestamp;
      address?: string;
    };
    operational: {
      status: 'active' | 'inactive' | 'maintenance' | 'offline';
      engineStatus: 'running' | 'idle' | 'off';
      speed: number; // km/h
      heading: number; // degrees
      fuelLevel: number; // 0-100%
      odometer: number; // km
      lastUpdate: FirebaseFirestore.Timestamp;
    };
    assignment: {
      driverId?: string;
      currentRouteId?: string;
      currentDeliveryId?: string;
      nextStopETA?: FirebaseFirestore.Timestamp;
    };
  };
  
  // Static Specifications
  specifications: {
    make: string;
    model: string;
    year: number;
    vehicleType: 'truck' | 'van' | 'pickup' | 'motorcycle';
    maxWeightCapacity: number; // kg
    maxVolumeCapacity: number; // m³
    fuelTankCapacity: number; // liters
  };
  
  // Operational Metadata
  metadata: {
    createdAt: FirebaseFirestore.Timestamp;
    updatedAt: FirebaseFirestore.Timestamp;
    isActive: boolean;
  };
}
```

**Example Document:**
```json
{
  "vehicleId": "VH001",
  "fleetId": "FLEET_CHICAGO",
  "licensePlate": "IL-123-ABC",
  "currentStatus": {
    "location": {
      "latitude": 41.8781,
      "longitude": -87.6298,
      "accuracy": 5.0,
      "timestamp": "2025-10-07T10:30:00Z",
      "address": "Downtown Chicago, IL"
    },
    "operational": {
      "status": "active",
      "engineStatus": "running",
      "speed": 45.5,
      "heading": 87,
      "fuelLevel": 72.3,
      "odometer": 125847,
      "lastUpdate": "2025-10-07T10:30:00Z"
    },
    "assignment": {
      "driverId": "DR007",
      "currentRouteId": "RT014",
      "currentDeliveryId": "DL-20251007-001",
      "nextStopETA": "2025-10-07T11:15:00Z"
    }
  },
  "specifications": {
    "make": "Ford",
    "model": "Transit",
    "year": 2023,
    "vehicleType": "van",
    "maxWeightCapacity": 1500,
    "maxVolumeCapacity": 12.5,
    "fuelTankCapacity": 80
  },
  "metadata": {
    "createdAt": "2025-10-01T00:00:00Z",
    "updatedAt": "2025-10-07T10:30:00Z",
    "isActive": true
  }
}
```

### **trips Subcollection**
**Path**: `/vehicles/{vehicleId}/trips/{tripId}`

```typescript
interface TripDocument {
  tripId: string;
  vehicleId: string;
  driverId: string;
  routeId: string;
  
  // Trip Timeline
  timeline: {
    startTime: FirebaseFirestore.Timestamp;
    endTime?: FirebaseFirestore.Timestamp;
    estimatedDuration: number; // minutes
    actualDuration?: number; // minutes
  };
  
  // Route Information
  route: {
    startLocation: GeoPoint;
    endLocation: GeoPoint;
    plannedDistance: number; // km
    actualDistance?: number; // km
    waypoints: Array<{
      location: GeoPoint;
      estimatedArrival: FirebaseFirestore.Timestamp;
      actualArrival?: FirebaseFirestore.Timestamp;
      stopType: 'pickup' | 'delivery' | 'fuel' | 'rest';
    }>;
  };
  
  // Performance Metrics
  performance: {
    averageSpeed: number; // km/h
    maxSpeed: number; // km/h
    fuelConsumption: number; // liters
    fuelEfficiency: number; // km/l
    idleTime: number; // minutes
    drivingTime: number; // minutes
  };
  
  // Status
  status: 'planned' | 'in_progress' | 'completed' | 'cancelled';
  metadata: {
    createdAt: FirebaseFirestore.Timestamp;
    updatedAt: FirebaseFirestore.Timestamp;
  };
}
```

## **📦 Delivery Collections**

### **deliveries Collection**
**Path**: `/deliveries/{deliveryId}`

```typescript
interface DeliveryDocument {
  deliveryId: string;
  customerId: string;
  
  // Assignment
  assignment: {
    vehicleId?: string;
    driverId?: string;
    routeId?: string;
    assignedAt?: FirebaseFirestore.Timestamp;
  };
  
  // Locations
  pickup: {
    address: {
      street: string;
      city: string;
      state: string;
      postalCode: string;
      country: string;
    };
    location: GeoPoint;
    contactInfo: {
      name: string;
      phone: string;
      instructions?: string;
    };
    scheduledTime: FirebaseFirestore.Timestamp;
    actualTime?: FirebaseFirestore.Timestamp;
  };
  
  delivery: {
    address: {
      street: string;
      city: string;
      state: string;
      postalCode: string;
      country: string;
    };
    location: GeoPoint;
    contactInfo: {
      name: string;
      phone: string;
      instructions?: string;
    };
    scheduledTime: FirebaseFirestore.Timestamp;
    actualTime?: FirebaseFirestore.Timestamp;
  };
  
  // Package Information
  package: {
    dimensions: {
      length: number; // cm
      width: number; // cm
      height: number; // cm
      weight: number; // kg
    };
    description: string;
    specialHandling?: string[];
    value: number; // USD
    packageCount: number;
  };
  
  // Real-time Status
  currentStatus: {
    status: 'pending' | 'assigned' | 'picked_up' | 'in_transit' | 'out_for_delivery' | 'delivered' | 'failed' | 'cancelled';
    substatus?: string; // "driver_en_route", "awaiting_customer", etc.
    estimatedDeliveryTime?: FirebaseFirestore.Timestamp;
    lastLocationUpdate?: {
      location: GeoPoint;
      timestamp: FirebaseFirestore.Timestamp;
      distanceToDestination?: number; // km
    };
    lastStatusUpdate: FirebaseFirestore.Timestamp;
  };
  
  // Priority and Service Level
  priority: 'low' | 'normal' | 'high' | 'urgent';
  serviceLevel: 'standard' | 'express' | 'same_day' | 'next_day';
  
  // Metadata
  metadata: {
    createdAt: FirebaseFirestore.Timestamp;
    updatedAt: FirebaseFirestore.Timestamp;
    createdBy: string;
  };
}
```

### **status_updates Subcollection**
**Path**: `/deliveries/{deliveryId}/status_updates/{updateId}`

```typescript
interface StatusUpdateDocument {
  updateId: string;
  deliveryId: string;
  
  // Status Change
  previousStatus: string;
  newStatus: string;
  statusMessage: string;
  
  // Context
  location?: GeoPoint;
  vehicleId?: string;
  driverId?: string;
  
  // Additional Information
  metadata: {
    timestamp: FirebaseFirestore.Timestamp;
    source: 'system' | 'driver' | 'customer' | 'agent';
    triggeredBy?: string;
    automated: boolean;
  };
  
  // Customer Notification
  notification: {
    sent: boolean;
    sentAt?: FirebaseFirestore.Timestamp;
    method?: 'sms' | 'email' | 'push' | 'multiple';
    templateUsed?: string;
  };
}
```

## **📍 Real-time Tracking Collections**

### **real_time_tracking Collection**
**Path**: `/real_time_tracking/{sessionId}`

```typescript
interface TrackingSessionDocument {
  sessionId: string;
  vehicleId: string;
  driverId: string;
  
  // Session Information
  session: {
    startTime: FirebaseFirestore.Timestamp;
    endTime?: FirebaseFirestore.Timestamp;
    isActive: boolean;
    trackingInterval: number; // seconds
  };
  
  // Current State
  current: {
    location: GeoPoint;
    speed: number; // km/h
    heading: number; // degrees
    accuracy: number; // meters
    altitude?: number; // meters
    lastUpdate: FirebaseFirestore.Timestamp;
  };
  
  // Associated Deliveries
  activeDeliveries: string[]; // deliveryIds
  
  // Performance Summary
  summary: {
    totalDistance: number; // km
    totalTime: number; // minutes
    averageSpeed: number; // km/h
    completedStops: number;
    pendingStops: number;
  };
}
```

### **location_updates Subcollection**
**Path**: `/real_time_tracking/{sessionId}/location_updates/{updateId}`

```typescript
interface LocationUpdateDocument {
  updateId: string;
  sessionId: string;
  
  // Location Data
  location: GeoPoint;
  accuracy: number; // meters
  speed: number; // km/h
  heading: number; // degrees
  altitude?: number; // meters
  
  // Vehicle State
  vehicleState: {
    engineStatus: 'running' | 'idle' | 'off';
    fuelLevel?: number; // percentage
    odometer?: number; // km
    temperature?: number; // celsius
  };
  
  // Context
  nearestStop?: {
    stopId: string;
    distance: number; // meters
    estimatedArrival: FirebaseFirestore.Timestamp;
  };
  
  // Metadata
  timestamp: FirebaseFirestore.Timestamp;
  source: 'gps' | 'manual' | 'estimated';
}
```

## **⚙️ Operational State Collections**

### **operational_state Collection**
**Path**: `/operational_state/{documentType}`

#### **fleet_summary Document**
```typescript
interface FleetSummaryDocument {
  // Real-time Fleet Metrics
  metrics: {
    totalVehicles: number;
    activeVehicles: number;
    availableVehicles: number;
    inMaintenanceVehicles: number;
    offlineVehicles: number;
  };
  
  // Performance Indicators
  performance: {
    averageSpeed: number; // km/h
    averageFuelLevel: number; // percentage
    totalDistanceTraveled: number; // km today
    completedDeliveries: number; // today
    pendingDeliveries: number;
    onTimeDeliveryRate: number; // percentage
  };
  
  // Geographic Distribution
  regions: Array<{
    regionId: string;
    regionName: string;
    activeVehicles: number;
    center: GeoPoint;
    radius: number; // km
  }>;
  
  // Last Update
  lastUpdated: FirebaseFirestore.Timestamp;
  calculatedAt: FirebaseFirestore.Timestamp;
}
```

#### **system_health Document**
```typescript
interface SystemHealthDocument {
  // Pipeline Health
  pipelines: {
    dataIngestion: {
      status: 'healthy' | 'degraded' | 'down';
      messagesPerMinute: number;
      latency: number; // milliseconds
      errorRate: number; // percentage
      lastCheck: FirebaseFirestore.Timestamp;
    };
    dataProcessing: {
      status: 'healthy' | 'degraded' | 'down';
      processingDelay: number; // seconds
      queueDepth: number;
      errorRate: number; // percentage
      lastCheck: FirebaseFirestore.Timestamp;
    };
  };
  
  // Database Health
  databases: {
    firestore: {
      status: 'healthy' | 'degraded' | 'down';
      readLatency: number; // milliseconds
      writeLatency: number; // milliseconds
      errorRate: number; // percentage
    };
    bigquery: {
      status: 'healthy' | 'degraded' | 'down';
      queryLatency: number; // milliseconds
      slotUtilization: number; // percentage
      errorRate: number; // percentage
    };
  };
  
  // External Services
  externalServices: {
    googleMaps: {
      status: 'available' | 'limited' | 'unavailable';
      responseTime: number; // milliseconds
      quotaRemaining: number;
    };
    weatherService: {
      status: 'available' | 'limited' | 'unavailable';
      responseTime: number; // milliseconds
      lastUpdate: FirebaseFirestore.Timestamp;
    };
  };
  
  // Overall Health Score
  overallHealth: {
    score: number; // 0-100
    status: 'healthy' | 'degraded' | 'critical';
    lastCalculated: FirebaseFirestore.Timestamp;
  };
}
```

## **🔍 Query Patterns & Indexing**

### **Composite Indexes Required**
```javascript
// Vehicle status queries
db.collection('vehicles')
  .where('currentStatus.operational.status', '==', 'active')
  .where('currentStatus.assignment.currentRouteId', '!=', null)
  .orderBy('currentStatus.operational.lastUpdate', 'desc');

// Index: vehicles
// Fields: currentStatus.operational.status (ASC), currentStatus.assignment.currentRouteId (ASC), currentStatus.operational.lastUpdate (DESC)

// Delivery tracking queries
db.collection('deliveries')
  .where('currentStatus.status', 'in', ['in_transit', 'out_for_delivery'])
  .where('priority', '==', 'high')
  .orderBy('delivery.scheduledTime', 'asc');

// Index: deliveries
// Fields: currentStatus.status (ASC), priority (ASC), delivery.scheduledTime (ASC)

// Real-time tracking queries
db.collection('real_time_tracking')
  .where('session.isActive', '==', true)
  .where('vehicleId', 'in', ['VH001', 'VH002', 'VH003'])
  .orderBy('current.lastUpdate', 'desc');

// Index: real_time_tracking
// Fields: session.isActive (ASC), vehicleId (ASC), current.lastUpdate (DESC)
```

### **Real-time Subscription Patterns**
```javascript
// Live vehicle tracking
const unsubscribe = db.collection('vehicles')
  .where('currentStatus.operational.status', '==', 'active')
  .onSnapshot((snapshot) => {
    snapshot.docChanges().forEach((change) => {
      if (change.type === 'added' || change.type === 'modified') {
        updateVehicleMarker(change.doc.data());
      }
    });
  });

// Delivery status updates
const unsubscribeDelivery = db.collection('deliveries')
  .doc(deliveryId)
  .collection('status_updates')
  .orderBy('metadata.timestamp', 'desc')
  .limit(1)
  .onSnapshot((snapshot) => {
    if (!snapshot.empty) {
      updateDeliveryStatus(snapshot.docs[0].data());
    }
  });
```

## **🚀 Performance Optimization**

### **Write Batching Strategy**
```javascript
// Batch vehicle status updates for efficiency
const batch = db.batch();

vehicleUpdates.forEach((update) => {
  const vehicleRef = db.collection('vehicles').doc(update.vehicleId);
  batch.update(vehicleRef, {
    'currentStatus.location': update.location,
    'currentStatus.operational.lastUpdate': admin.firestore.Timestamp.now()
  });
});

await batch.commit();
```

### **Cache-first Read Strategy**
```javascript
// Enable offline persistence for real-time data
firebase.firestore().enablePersistence({
  synchronizeTabs: true
});

// Use cached data for initial load, then sync with server
const options = {
  source: 'cache'
};

try {
  const snapshot = await db.collection('vehicles').get(options);
  displayVehicles(snapshot.docs);
} catch (e) {
  // Fall back to server if cache is empty
  const snapshot = await db.collection('vehicles').get();
  displayVehicles(snapshot.docs);
}
```

## **🔒 Security Rules**

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Vehicle data - read access for all authenticated users, write for system only
    match /vehicles/{vehicleId} {
      allow read: if request.auth != null;
      allow write: if request.auth.token.role == 'system' 
                   || request.auth.token.role == 'admin';
      
      match /trips/{tripId} {
        allow read: if request.auth != null;
        allow write: if request.auth.token.role == 'driver' 
                    && resource.data.driverId == request.auth.uid;
      }
    }
    
    // Delivery data - customer can read their own deliveries
    match /deliveries/{deliveryId} {
      allow read: if request.auth != null 
                  && (request.auth.token.role == 'admin'
                      || request.auth.token.role == 'driver'
                      || resource.data.customerId == request.auth.uid);
      allow write: if request.auth.token.role == 'system' 
                   || request.auth.token.role == 'admin';
    }
    
    // Real-time tracking - restricted to assigned drivers
    match /real_time_tracking/{sessionId} {
      allow read: if request.auth != null;
      allow write: if request.auth.token.role == 'driver'
                   && resource.data.driverId == request.auth.uid;
    }
    
    // Operational state - read-only for most users
    match /operational_state/{document=**} {
      allow read: if request.auth != null;
      allow write: if request.auth.token.role == 'system';
    }
  }
}
```

This Firestore schema provides the **real-time operational backbone** for the Intelligent DataOps Platform, enabling instant updates, live tracking, and responsive user experiences across all logistics operations.