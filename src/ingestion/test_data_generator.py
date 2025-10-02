"""
Test Data Generator for IoT Telemetry
Generates sample data to test the pipeline

This script creates realistic IoT telemetry data for testing:
- Vehicle GPS coordinates
- Speed and fuel level data  
- Engine status updates
- Publishes to Pub/Sub for pipeline testing
"""

import json
import random
import time
from datetime import datetime, timedelta
from typing import Dict, List

from google.cloud import pubsub_v1


class IoTDataGenerator:
    """Generate realistic IoT telemetry data for testing."""
    
    def __init__(self, project_id: str, topic_name: str):
        """Initialize the data generator.
        
        Args:
            project_id: GCP project ID
            topic_name: Pub/Sub topic to publish to
        """
        self.project_id = project_id
        self.topic_name = topic_name
        self.publisher = pubsub_v1.PublisherClient()
        self.topic_path = self.publisher.topic_path(project_id, topic_name)
        
        # Fleet configuration
        self.vehicles = self._generate_vehicle_fleet()
        self.base_locations = self._get_base_locations()
    
    def _generate_vehicle_fleet(self) -> List[Dict]:
        """Generate a fleet of test vehicles."""
        vehicles = []
        vehicle_types = ['truck', 'van', 'pickup']
        
        for i in range(5):  # Small fleet for cost control
            vehicle = {
                'vehicle_id': f'VH{i+1:03d}',
                'vehicle_type': random.choice(vehicle_types),
                'max_speed': random.randint(80, 120),
                'fuel_capacity': random.randint(50, 200),
                'driver_id': f'DR{i+1:03d}'
            }
            vehicles.append(vehicle)
        
        return vehicles
    
    def _get_base_locations(self) -> List[Dict]:
        """Define base locations for realistic routes."""
        return [
            {'name': 'Chicago Distribution', 'lat': 41.8781, 'lon': -87.6298},
            {'name': 'Indianapolis Hub', 'lat': 39.7684, 'lon': -86.1581}, 
            {'name': 'Milwaukee Depot', 'lat': 43.0389, 'lon': -87.9065},
            {'name': 'Detroit Center', 'lat': 42.3314, 'lon': -83.0458},
            {'name': 'Columbus Terminal', 'lat': 39.9612, 'lon': -82.9988}
        ]
    
    def generate_telemetry_message(self, vehicle: Dict) -> Dict:
        """Generate a single telemetry message for a vehicle.
        
        Args:
            vehicle: Vehicle configuration
            
        Returns:
            Dict: Telemetry message
        """
        # Simulate vehicle movement
        base_location = random.choice(self.base_locations)
        
        # Add some random movement around base location
        lat_offset = random.uniform(-0.1, 0.1)  # ~11km radius
        lon_offset = random.uniform(-0.1, 0.1)
        
        # Simulate realistic speed patterns
        if random.random() < 0.1:  # 10% chance of being stationary
            speed = 0
        elif random.random() < 0.3:  # 30% chance of city driving
            speed = random.uniform(5, 50)
        else:  # Highway driving
            speed = random.uniform(50, vehicle['max_speed'])
        
        # Fuel level decreases over time (simplified)
        fuel_level = max(10, random.uniform(20, 100))
        
        # Engine status based on movement
        if speed > 0:
            engine_status = random.choice(['running', 'running', 'running', 'idle'])
        else:
            engine_status = random.choice(['idle', 'off'])
        
        message = {
            'vehicle_id': vehicle['vehicle_id'],
            'device_type': 'gps_tracker',
            'timestamp': datetime.utcnow().isoformat() + 'Z',
            'latitude': base_location['lat'] + lat_offset,
            'longitude': base_location['lon'] + lon_offset,
            'speed_kmh': round(speed, 2),
            'fuel_level': round(fuel_level, 2),
            'engine_status': engine_status,
            'driver_id': vehicle['driver_id'],
            'route_id': f'RT{random.randint(1, 10):03d}',
            'odometer': random.randint(50000, 200000),
            'temperature': random.randint(-10, 35),  # Engine temp
            'generated_at': datetime.utcnow().isoformat()
        }
        
        # Occasionally add some data quality issues for testing
        if random.random() < 0.05:  # 5% chance of missing data
            fields_to_remove = random.sample(
                ['speed_kmh', 'fuel_level', 'latitude', 'longitude'], 
                k=random.randint(1, 2)
            )
            for field in fields_to_remove:
                message.pop(field, None)
        
        return message
    
    def publish_message(self, message: Dict) -> None:
        """Publish a message to Pub/Sub.
        
        Args:
            message: Telemetry message to publish
        """
        try:
            # Convert to JSON and encode
            message_json = json.dumps(message)
            message_bytes = message_json.encode('utf-8')
            
            # Publish to Pub/Sub with timeout handling
            future = self.publisher.publish(self.topic_path, message_bytes)
            
            try:
                future.result(timeout=10.0)  # Wait for publish to complete with 10s timeout
                print(f"Published message for vehicle {message.get('vehicle_id', 'unknown')}")
            except Exception as timeout_error:
                print(f"Timeout publishing message for vehicle {message.get('vehicle_id', 'unknown')}: {timeout_error}")
                # Message may still be published, just acknowledgment timed out
            
        except Exception as e:
            print(f"Error publishing message: {e}")
    
    def generate_batch_data(self, num_messages: int = 10, delay_seconds: float = 1.0):
        """Generate a batch of test messages.
        
        Args:
            num_messages: Number of messages to generate
            delay_seconds: Delay between messages
        """
        print(f"Generating {num_messages} test messages...")
        print(f"Publishing to topic: {self.topic_path}")
        
        for i in range(num_messages):
            # Pick random vehicle
            vehicle = random.choice(self.vehicles)
            
            # Generate and publish message
            message = self.generate_telemetry_message(vehicle)
            self.publish_message(message)
            
            # Add delay between messages
            if i < num_messages - 1:
                time.sleep(delay_seconds)
        
        print(f"Completed generating {num_messages} messages")
    
    def generate_continuous_data(self, duration_minutes: int = 10, messages_per_minute: int = 6):
        """Generate continuous data stream for testing.
        
        Args:
            duration_minutes: How long to generate data
            messages_per_minute: Rate of message generation
        """
        print(f"Starting continuous data generation...")
        print(f"Duration: {duration_minutes} minutes")
        print(f"Rate: {messages_per_minute} messages/minute")
        
        end_time = datetime.utcnow() + timedelta(minutes=duration_minutes)
        message_interval = 60.0 / messages_per_minute
        
        message_count = 0
        while datetime.utcnow() < end_time:
            # Pick random vehicle
            vehicle = random.choice(self.vehicles)
            
            # Generate and publish message
            message = self.generate_telemetry_message(vehicle)
            self.publish_message(message)
            
            message_count += 1
            
            # Wait for next message
            time.sleep(message_interval)
        
        print(f"Completed continuous generation: {message_count} messages")


def main():
    """Main function for command line usage."""
    import argparse
    
    parser = argparse.ArgumentParser(description='Generate IoT telemetry test data')
    parser.add_argument('--project', required=True, help='GCP Project ID')
    parser.add_argument('--topic', default='iot-telemetry', help='Pub/Sub topic name')
    parser.add_argument('--batch-size', type=int, default=10, help='Number of messages for batch mode')
    parser.add_argument('--continuous', action='store_true', help='Run in continuous mode')
    parser.add_argument('--duration', type=int, default=10, help='Duration in minutes for continuous mode')
    parser.add_argument('--rate', type=int, default=6, help='Messages per minute for continuous mode')
    
    args = parser.parse_args()
    
    # Create data generator
    generator = IoTDataGenerator(args.project, args.topic)
    
    if args.continuous:
        generator.generate_continuous_data(args.duration, args.rate)
    else:
        generator.generate_batch_data(args.batch_size)


if __name__ == '__main__':
    main()