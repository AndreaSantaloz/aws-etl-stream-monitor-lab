import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job # IMPORTANTE
from pyspark.sql.functions import col, sum as spark_sum, avg, substring

# Añadimos JOB_NAME y usamos table_name para consistencia
args = getResolvedOptions(sys.argv, ['JOB_NAME', 'database', 'table_name', 'output_path'])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session # Sesión de spark
job = Job(glueContext)
job.init(args['JOB_NAME'], args) # Inicialización obligatoria

# Leer desde Glue Catalog
dynamic_frame = glueContext.create_dynamic_frame.from_catalog(
    database=args['database'],
    table_name=args['table_name']
)

df = dynamic_frame.toDF()

# Transformación
df = df.withColumn("fecha", substring(col("timestamp"), 1, 7))
daily_df = df.groupBy("fecha", "departamento") \
    .agg(
        spark_sum(col("estres_index").cast("double")).alias("estres_total"),
        avg(col("latencia").cast("double")).alias("latencia_promedio")
    ) \
    .orderBy("fecha", "departamento")
# Escritura modo Spark (más limpio para sobrescribir y particionar)
daily_df.write \
    .mode("overwrite") \
    .partitionBy("fecha") \
    .parquet(args['output_path'])

job.commit() # Cierre obligatorio