#!/bin/bash

# Shell-based test data generator using gcloud CLI
# Works around Python 3.13 compatibility issues

PROJECT_ID="manish-sandpit"
TOPIC="iot-telemetry"
NUM_MESSAGES=${1:-5}

echo "🚀 Generating $NUM_MESSAGES test messages using gcloud CLI..."
echo "📍 Project: $PROJECT_ID"
echo "📡 Topic: $TOPIC"
echo ""

# Vehicle fleet for testing
VEHICLES=("VH001" "VH002" "VH003" "VH004" "VH005")
DEVICE_TYPES=("gps_tracker" "obd_device" "fuel_sensor")
ENGINE_STATUS=("running" "idle" "off")

for i in $(seq 1 $NUM_MESSAGES); do
    # Random selections
    VEHICLE=${VEHICLES[$((RANDOM % ${#VEHICLES[@]}))]}
    DEVICE=${DEVICE_TYPES[$((RANDOM % ${#DEVICE_TYPES[@]}))]}
    STATUS=${ENGINE_STATUS[$((RANDOM % ${#ENGINE_STATUS[@]}))]}
    
    # Random coordinates around Chicago area
    LAT=$(echo "41.8781 + ($RANDOM % 200 - 100) * 0.001" | bc -l)
    LON=$(echo "-87.6298 + ($RANDOM % 200 - 100) * 0.001" | bc -l)
    
    # Random values
    SPEED=$((RANDOM % 120))
    FUEL=$((RANDOM % 100))
    TEMP=$((RANDOM % 40 - 10))
    ODOMETER=$((50000 + RANDOM % 150000))
    
    # Create timestamp
    TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Build JSON message
    MESSAGE=$(cat <<EOF
{
    "vehicle_id": "$VEHICLE",
    "device_type": "$DEVICE",
    "timestamp": "$TIMESTAMP",
    "latitude": $LAT,
    "longitude": $LON,
    "speed_kmh": $SPEED,
    "fuel_level": $FUEL,
    "engine_status": "$STATUS",
    "driver_id": "DR$(printf "%03d" $((RANDOM % 10 + 1)))",
    "route_id": "RT$(printf "%03d" $((RANDOM % 20 + 1)))",
    "odometer": $ODOMETER,
    "temperature": $TEMP,
    "generated_at": "$TIMESTAMP",
    "data_source": "shell_script"
}
EOF
)

    echo "📤 Publishing message $i for vehicle $VEHICLE..."
    
    # Publish using gcloud (this actually works)
    echo "$MESSAGE" | gcloud pubsub topics publish $TOPIC --message=-
    
    if [ $? -eq 0 ]; then
        echo "✅ Message $i published successfully"
    else
        echo "❌ Failed to publish message $i"
    fi
    
    # Small delay between messages
    sleep 0.5
done

echo ""
echo "🎉 Completed generating $NUM_MESSAGES test messages"
echo "📊 Check with: gcloud pubsub subscriptions pull iot-telemetry-subscription --limit=3 --auto-ack"