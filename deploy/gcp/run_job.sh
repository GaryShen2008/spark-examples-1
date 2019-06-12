#!/usr/bin/env bash

if [[ "$1" = "" ]]
then
  echo "Usage: $0 <Spark master IP>"
  exit 1
fi

set -ex

#
# Comment/uncomment for job parameters.
#

# The job to run; for a given dataset, ConvertToParquet needs to be run before MLBenchmark
JOB=ConvertToCsv
#JOB=ConvertToParquet
#JOB=MLBenchmark
#JOB=ConvertToLibSVM

# The period to benchmark
#PERIOD=2007Q4
#PERIOD=2000-2006
PERIOD=2000-2009
#PERIOD=all

# CPU or GPU
DEVICE=gpu
#DEVICE=cpu

# Max tree depth
MAX_DEPTH=8
#MAX_DEPTH=20
GROW_POLICY=depthwise
#GROW_POLICY=lossguide

#PERF_FILES=/data/mortgage/perf/Performance_2007Q4*
#PERF_FILES=/data/mortgage/perf/Performance_200[0-6]*
PERF_FILES=/data/mortgage/perf/Performance_200[0-9]*
#PERF_FILES=/data/mortgage/perf/Performance_*
#ACQ_FILES=/data/mortgage/acq/Acquisition_2007Q4*
#ACQ_FILES=/data/mortgage/acq/Acquisition_200[0-6]*
ACQ_FILES=/data/mortgage/acq/Acquisition_200[0-9]*
#ACQ_FILES=/data/mortgage/acq/Acquisition_*

# Whether to use external memory
EXTERNAL_MEMORY=false
#EXTERNAL_MEMORY=true

#
# Probably don't need to change anything below.
#

# External IP of the Spark master node
SPARK_MASTER_IP=$1

case "${JOB}" in
ConvertToCsv)
  OUTPUT_DIR=/data/spark/csv/${PERIOD}
  ;;
ConvertToParquet | MLBenchmark)
  OUTPUT_DIR=/data/spark/pq/${PERIOD}
  ;;
ConvertToLibSVM)
  OUTPUT_DIR=/data/mortgage/libsvm/${PERIOD}
  ;;
esac

BENCHMARK_DIR=/data/spark/benchmark

# Number of runs per benchmark
SAMPLES=1

# Number of Rounds
ROUNDS=100

# Number of workers
WORKERS=20

# Number of threads per worker
THREADS=23

case "${DEVICE}" in
cpu)
  TREE_METHOD=hist
  if [[ ${EXTERNAL_MEMORY} == "true" ]]; then
    TREE_METHOD=approx
  fi
  ;;
gpu)
  TREE_METHOD=gpu_hist
  ;;
esac

case "${JOB}" in
ConvertToCsv | ConvertToParquet | ConvertToLibSVM )
  /opt/spark/bin/spark-submit \
  --class ai.rapids.sparkexamples.mortgage.${JOB} \
  --master spark://${SPARK_MASTER_IP}:7077 \
  --deploy-mode cluster \
  --driver-memory 2G \
  --executor-memory 130G \
  --conf spark.sql.shuffle.partitions=1440 \
  --conf spark.default.parallelism=1440 \
  /data/spark/jars/mortgage-assembly-0.1.0-SNAPSHOT.jar \
  ${PERF_FILES} \
  ${ACQ_FILES} \
  ${OUTPUT_DIR}
  ;;
MLBenchmark)
  /opt/spark/bin/spark-submit \
  --class ai.rapids.sparkexamples.mortgage.${JOB} \
  --master spark://${SPARK_MASTER_IP}:7077 \
  --deploy-mode cluster \
  --driver-memory 10G \
  --executor-memory 130G \
  --conf spark.task.cpus=${THREADS} \
  --conf spark.executorEnv.NCCL_DEBUG=INFO \
  /data/spark/jars/mortgage-assembly-0.1.0-SNAPSHOT.jar \
  ${OUTPUT_DIR} \
  ${BENCHMARK_DIR}/${PERIOD}-${DEVICE}-depth-${MAX_DEPTH} \
  ${WORKERS} \
  ${SAMPLES} \
  ${ROUNDS} \
  ${THREADS} \
  ${TREE_METHOD} \
  ${MAX_DEPTH} \
  ${GROW_POLICY} \
  ${EXTERNAL_MEMORY}
  ;;
esac
