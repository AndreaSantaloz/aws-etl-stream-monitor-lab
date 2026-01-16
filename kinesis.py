import boto3
import json
import time
from loguru import logger
import datetime

# CONFIGURACIÓN
STREAM_NAME = 'employees'
REGION = 'us-east-1' 
INPUT_FILE = 'employee-dataset.json'

kinesis = boto3.client('kinesis', region_name=REGION)

def load_data(file_path):
    with open(file_path, 'r') as f:
        return json.load(f)

def run_producer():
    data = load_data(INPUT_FILE)
    records_sent = 0
    
    # IMPORTANTE: Tu nuevo JSON es una lista directa, no tiene 'included'
    logger.info(f"Iniciando transmisión al stream: {STREAM_NAME}...")
    
    # Iteramos directamente sobre la lista de registros de empleados
    for registro in data:
        # Extraemos los campos del nuevo formato para el log y la lógica
        id_emp = registro.get('id_empleado')
        depto = registro.get('departamento')
        timestamp = registro.get('timestamp')
        metricas = registro.get('metricas', {})
        
        # Estructura del mensaje a enviar (adaptado a las nuevas columnas)
        payload = {
            'event_id': registro.get('event_id'),
            'timestamp': timestamp,
            'id_empleado': id_emp,
            'departamento': depto,
            'estado': metricas.get('estado'),
            'latencia': metricas.get('latencia_red'),
            'tareas_pendientes': metricas.get('tareas_pendientes'),
            'estres_index': metricas.get('estres_index'),
            'geoloc': registro.get('geoloc')
        }
        
        # Enviar a Kinesis
        response = kinesis.put_record(
            StreamName=STREAM_NAME,
            Data=json.dumps(payload),
            # Usamos el departamento o el ID como clave de partición
            PartitionKey=id_emp
        )
        
        records_sent += 1
        logger.info(f"Registro enviado al shard {response['ShardId']} con SequenceNumber {response['SequenceNumber']}")
        logger.info(f"Enviado [Empleado: {id_emp}]: Estado {metricas.get('estado')} en {depto}")
        
        # Pequeña pausa para simular streaming y no saturar de golpe
        time.sleep(0.05) 

    logger.info(f"Fin de la transmisión. Total registros enviados: {records_sent}")

if __name__ == '__main__':
    run_producer()