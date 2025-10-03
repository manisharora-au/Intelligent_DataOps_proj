"""
Setup file for Dataflow pipeline dependencies
"""

from setuptools import setup, find_packages

setup(
    name='iot-telemetry-pipeline',
    version='1.0',
    description='IoT Telemetry Processing Pipeline',
    packages=find_packages(),
    install_requires=[
        'apache-beam[gcp]==2.57.0',
        'google-cloud-bigquery',
        'google-cloud-pubsub',
        'google-cloud-storage'
    ],
)