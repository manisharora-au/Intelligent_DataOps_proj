"""
Basic Dataflow Pipeline for Intelligent DataOps Platform
Cost-optimized pipeline for IoT telemetry data processing

This pipeline demonstrates:
- Reading from Pub/Sub
- Basic data transformation
- Writing to BigQuery and Cloud Storage
- Error handling and monitoring
"""

import argparse
import json
import logging 
from datetime import datetime, timezone
from typing import Dict, Any

import apache_beam as beam
from apache_beam.options.pipeline_options import PipelineOptions
from apache_beam.transforms import window


class ParsePubSubMessage(beam.DoFn):
    """Parse incoming Pub/Sub messages and validate data structure."""
    
    def process(self, element):
        """Process a single Pub/Sub message.
        
        Args:
            element: Raw Pub/Sub message
            
        Yields:
            Dict: Parsed message data or error record
        """
        try:
            # Parse JSON message
            message_data = json.loads(element.decode('utf-8'))
            
            # Add processing timestamp
            message_data['processed_at'] = datetime.now(timezone.utc).isoformat()
            
            # Validate required fields for IoT telemetry
            required_fields = ['vehicle_id', 'timestamp', 'device_type']
            if all(field in message_data for field in required_fields):
                # Tag as valid message
                yield beam.pvalue.TaggedOutput('valid', message_data)
            else:
                # Tag as invalid message
                error_record = {
                    'raw_message': element.decode('utf-8'),
                    'error': f'Missing required fields: {required_fields}',
                    'processed_at': datetime.utcnow().isoformat()
                }
                yield beam.pvalue.TaggedOutput('invalid', error_record)
                
        except json.JSONDecodeError as e:
            # Handle JSON parsing errors
            error_record = {
                'raw_message': element.decode('utf-8'),
                'error': f'JSON parsing error: {str(e)}',
                'processed_at': datetime.utcnow().isoformat()
            }
            yield beam.pvalue.TaggedOutput('invalid', error_record)
        except Exception as e:
            # Handle unexpected errors
            error_record = {
                'raw_message': str(element),
                'error': f'Unexpected error: {str(e)}',
                'processed_at': datetime.utcnow().isoformat()
            }
            yield beam.pvalue.TaggedOutput('invalid', error_record)


class EnrichTelemetryData(beam.DoFn):
    """Enrich telemetry data with additional metadata and calculations."""
    
    def process(self, element):
        """Enrich telemetry data.
        
        Args:
            element: Valid telemetry message
            
        Yields:
            Dict: Enriched telemetry data
        """
        try:
            # Add data quality metrics
            element['data_quality_score'] = self._calculate_quality_score(element)
            
            # Add geospatial calculations if coordinates available
            if 'latitude' in element and 'longitude' in element:
                element['location_valid'] = self._validate_coordinates(
                    element['latitude'], element['longitude']
                )
            
            # Add derived fields
            if 'speed_kmh' in element:
                element['speed_category'] = self._categorize_speed(element['speed_kmh'])
            
            # Store raw data as JSON string
            element['raw_data'] = json.dumps(element)
            
            yield element
            
        except Exception as e:
            logging.error(f"Error enriching data: {str(e)}")
            # Still yield original data on enrichment failure
            element['enrichment_error'] = str(e)
            yield element
    
    def _calculate_quality_score(self, data: Dict[str, Any]) -> float:
        """Calculate data quality score based on completeness."""
        expected_fields = [
            'vehicle_id', 'timestamp', 'device_type', 'latitude', 
            'longitude', 'speed_kmh', 'fuel_level', 'engine_status'
        ]
        
        present_fields = sum(1 for field in expected_fields if field in data and data[field] is not None)
        return present_fields / len(expected_fields)
    
    def _validate_coordinates(self, lat: float, lon: float) -> bool:
        """Validate GPS coordinates are within reasonable bounds."""
        return -90 <= lat <= 90 and -180 <= lon <= 180
    
    def _categorize_speed(self, speed: float) -> str:
        """Categorize speed into ranges."""
        if speed <= 0:
            return 'stationary'
        elif speed <= 30:
            return 'slow'
        elif speed <= 60:
            return 'moderate'
        elif speed <= 100:
            return 'fast'
        else:
            return 'very_fast'


def create_bigquery_schema():
    """Create BigQuery schema for telemetry data."""
    return "timestamp:TIMESTAMP,vehicle_id:STRING,device_type:STRING,latitude:FLOAT,longitude:FLOAT,speed_kmh:FLOAT,fuel_level:FLOAT,engine_status:STRING,driver_id:STRING,route_id:STRING,odometer:INTEGER,temperature:INTEGER,generated_at:TIMESTAMP,processed_at:TIMESTAMP,data_quality_score:FLOAT,location_valid:BOOLEAN,speed_category:STRING,raw_data:STRING"


def run_pipeline(argv=None):
    """Run the Dataflow pipeline."""
    
    # Parse command line arguments
    parser = argparse.ArgumentParser()
    parser.add_argument(
        '--project',
        required=True,
        help='GCP Project ID'
    )
    parser.add_argument(
        '--input_subscription',
        required=True,
        help='Pub/Sub subscription to read from'
    )
    parser.add_argument(
        '--output_table',
        required=True,
        help='BigQuery table to write to (project:dataset.table)'
    )
    parser.add_argument(
        '--error_table',
        required=True,
        help='BigQuery table for error records'
    )
    parser.add_argument(
        '--temp_location',
        required=True,
        help='GCS bucket for temporary files'
    )
    parser.add_argument(
        '--streaming',
        default=True,
        type=bool,
        help='Run as streaming pipeline'
    )
    
    args, pipeline_args = parser.parse_known_args(argv)
    
    # Set pipeline options
    pipeline_options = PipelineOptions(pipeline_args)
    pipeline_options.view_as(beam.options.pipeline_options.StandardOptions).streaming = args.streaming
    pipeline_options.view_as(beam.options.pipeline_options.GoogleCloudOptions).project = args.project
    pipeline_options.view_as(beam.options.pipeline_options.GoogleCloudOptions).temp_location = args.temp_location
    
    # Create and run pipeline
    with beam.Pipeline(options=pipeline_options) as pipeline:
        
        # Read from Pub/Sub
        messages = (
            pipeline
            | 'Read from Pub/Sub' >> beam.io.ReadFromPubSub(
                subscription=args.input_subscription
            )
        )
        
        # Parse and validate messages
        parsed_messages = (
            messages
            | 'Parse Messages' >> beam.ParDo(ParsePubSubMessage()).with_outputs(
                'valid', 'invalid'
            )
        )
        
        # Process valid messages
        enriched_data = (
            parsed_messages.valid
            | 'Enrich Data' >> beam.ParDo(EnrichTelemetryData())
        )
        
        # Write to BigQuery (with windowing for streaming)
        if args.streaming:
            enriched_data = (
                enriched_data
                | 'Window into Fixed Intervals' >> beam.WindowInto(
                    window.FixedWindows(30)  # 30-second windows for faster testing
                )
            )
        
        # Write valid data to BigQuery
        (
            enriched_data
            | 'Write to BigQuery' >> beam.io.WriteToBigQuery(
                table=args.output_table,
                schema=create_bigquery_schema(),
                create_disposition=beam.io.BigQueryDisposition.CREATE_IF_NEEDED,
                write_disposition=beam.io.BigQueryDisposition.WRITE_APPEND
            )
        )
        
        # Write error data to separate table
        (
            parsed_messages.invalid
            | 'Write Errors to BigQuery' >> beam.io.WriteToBigQuery(
                table=args.error_table,
                schema="raw_message:STRING,error:STRING,processed_at:TIMESTAMP",
                create_disposition=beam.io.BigQueryDisposition.CREATE_IF_NEEDED,
                write_disposition=beam.io.BigQueryDisposition.WRITE_APPEND
            )
        )


if __name__ == '__main__':
    logging.getLogger().setLevel(logging.INFO)
    run_pipeline()