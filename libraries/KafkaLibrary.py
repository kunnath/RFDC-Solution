# KafkaLibrary.py
"""
Custom Robot Framework library for Kafka interface.
"""

from robot.api.deco import keyword
import os
import time
from robot.libraries.BuiltIn import BuiltIn

try:
    from confluent_kafka import Producer, Consumer
    _HAS_CONFLUENT = True
except Exception:
    _HAS_CONFLUENT = False


class KafkaLibrary:
    def __init__(self):
        # Determine whether to use a mock implementation
        self.use_mock = False
        # Robot variable KAFKA_MOCK can be passed via --variable KAFKA_MOCK:True
        try:
            bi = BuiltIn()
            val = bi.get_variable_value('${KAFKA_MOCK}', None)
            if str(val).lower() in ('1', 'true', 'yes'):
                self.use_mock = True
        except Exception:
            pass
        # environment variable fallback
        if os.environ.get('KAFKA_MOCK', '').lower() in ('1', 'true', 'yes'):
            self.use_mock = True

        if not self.use_mock and _HAS_CONFLUENT:
            # initialize real kafka producer/consumer
            cfg = {'bootstrap.servers': os.environ.get('KAFKA_BOOTSTRAP', 'localhost:9092')}
            self.producer = Producer(cfg)
            self.consumer = Consumer({'bootstrap.servers': cfg['bootstrap.servers'], 'group.id': 'robot'})
        else:
            # in-memory mock
            self._topics = {}

    @keyword
    def produce(self, topic, value):
        if self.use_mock or not _HAS_CONFLUENT:
            self._topics.setdefault(topic, []).append(value)
        else:
            self.producer.produce(topic, value)
            self.producer.flush()

    @keyword
    def consume(self, topic, timeout=1.0):
        if self.use_mock or not _HAS_CONFLUENT:
            start = time.time()
            while time.time() - start < float(timeout):
                lst = self._topics.get(topic, [])
                if lst:
                    return lst.pop(0)
                time.sleep(0.1)
            return None
        else:
            self.consumer.subscribe([topic])
            msg = self.consumer.poll(float(timeout))
            if msg is None:
                return None
            return msg.value().decode('utf-8') if isinstance(msg.value(), bytes) else msg.value()
