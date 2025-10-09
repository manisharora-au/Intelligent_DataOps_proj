"""
Setup file for Dataflow pipeline dependencies
Used for Google Cloud Dataflow Flex Template deployments and package distribution
"""

from setuptools import setup, find_packages

setup(
    name='iot-telemetry-pipeline',
    version='1.0.0',
    description='IoT Telemetry Processing Pipeline for Intelligent DataOps Platform',
    author='Intelligent DataOps Team',
    python_requires='>=3.12',
    packages=find_packages(),
    install_requires=[
        # Apache Beam (stable version with working DirectRunner)
        'apache-beam[gcp]==2.56.0',
        
        # Core Google Cloud libraries (exact versions for stability)
        'google-cloud-pubsub==2.31.1',
        'google-cloud-bigquery==3.27.0',
        'google-cloud-bigquery-storage==2.33.1',
        'google-cloud-storage==2.19.0',
        'google-cloud-datastore==2.21.0',
        'google-cloud-core==2.4.3',
        
        # Data processing libraries
        'numpy==1.26.4',
        'pyarrow==14.0.2',
        'pyarrow-hotfix==0.7',
        'fastavro==1.12.0',
        
        # Core utilities
        'python-dateutil==2.9.0.post0',
        'pytz==2025.2',
        'fasteners==0.20',
        
        # Protocol Buffers and gRPC
        'protobuf==4.25.8',
        'grpcio==1.65.5',
    ],
    extras_require={
        'ai': [
            'google-cloud-aiplatform==1.119.0',
            'google-cloud-dlp==3.32.0',
            'google-cloud-language==2.17.2',
            'google-cloud-vision==3.10.2',
        ],
        'dev': [
            'pytest>=7.4.0',
            'pytest-mock>=3.12.0',
        ]
    },
    entry_points={
        'console_scripts': [
            'iot-pipeline=basic_pipeline:run_pipeline',
        ],
    },
    classifiers=[
        'Development Status :: 4 - Beta',
        'Intended Audience :: Developers',
        'Programming Language :: Python :: 3.12',
        'Topic :: Software Development :: Libraries :: Python Modules',
    ],
)