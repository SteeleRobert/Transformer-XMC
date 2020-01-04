#!/bin/bash

GPUS=$1
DATASET=$2
MODEL_TYPE=$3
MODEL_NAME=$4

#INDEXER_NAME=pifa-a5-s0
INDEXER_NAME=one-vs-all
OUTPUT_DIR=save_models/${DATASET}/${INDEXER_NAME}
MAX_XSEQ_LEN=128

# set per_gpu_bsz by model_type
if [ ${MODEL_TYPE} == "bert" ] || [ ${MODEL_TYPE} == "roberta" ]; then
  PER_GPU_TRN_BSZ=8   # 2080Ti
  PER_GPU_VAL_BSZ=32
  GRAD_ACCU_STEPS=1
elif [ ${MODEL_TYPE} == "xlnet" ]; then
  PER_GPU_TRN_BSZ=50  # 2080Ti
  PER_GPU_VAL_BSZ=100
  GRAD_ACCU_STEPS=2
else
  echo "model_type not support [ bert | roberta | xlnet ]"
  exit
fi

# set hyper-params by dataset
if [ ${DATASET} == "Eurlex-4K" ]; then
  MAX_STEPS_ARR=( 8000 )
  WARMUP_STEPS_ARR=( 800 )
  LOGGING_STEPS=50
  SAVE_STEPS=400
  LEARNING_RATE_ARR=( 1e-4 )
elif [ ${DATASET} == "Wiki10-31K" ]; then
  MAX_STEPS_ARR=( 4000 )
  WARMUP_STEPS_ARR=( 400 )
  LOGGING_STEPS=50
  SAVE_STEPS=200
  LEARNING_RATE_ARR=( 5e-5 )
elif [ ${DATASET} == "AmazonCat-13K" ]; then
  MAX_STEPS_ARR=( 8000 )
  WARMUP_STEPS_ARR=( 2000 )
  LOGGING_STEPS=100
  SAVE_STEPS=2000
  LEARNING_RATE_ARR=( 1e-4 )
elif [ ${DATASET} == "Wiki-500K" ]; then
  MAX_STEPS_ARR=( 40000 )
  WARMUP_STEPS_ARR=( 4000 )
  LOGGING_STEPS=100
  SAVE_STEPS=4000
  LEARNING_RATE_ARR=( 1e-4 )
else
  echo "dataset not support [ Eurlex-4K | Wiki10-31K | AmazonCat-13K | Wiki-500K ]"
  exit
fi

for idx in "${!MAX_STEPS_ARR[@]}"; do
  MAX_STEPS=${MAX_STEPS_ARR[${idx}]}
  WARMUP_STEPS=${WARMUP_STEPS_ARR[${idx}]}
  for LEARNING_RATE in "${LEARNING_RATE_ARR[@]}"; do
    # train transformer models on XMC preprocessed data
    MODEL_DIR=${OUTPUT_DIR}/matcher-cased/${MODEL_NAME}_seq-${MAX_XSEQ_LEN}/step-${MAX_STEPS}_warmup-${WARMUP_STEPS}_lr-${LEARNING_RATE}
    mkdir -p ${MODEL_DIR}
    CUDA_VISIBLE_DEVICES=${GPUS} python -u -m xbert.matcher.transformer \
      -m ${MODEL_TYPE} -n ${MODEL_NAME} \
      -i ${OUTPUT_DIR}/data-bin-cased/${MODEL_NAME}_seq-${MAX_XSEQ_LEN}/data_dict.pt \
      -o ${MODEL_DIR} --overwrite_output_dir \
      --do_train --do_eval --stop_by_dev --fp16 \
      --per_gpu_train_batch_size ${PER_GPU_TRN_BSZ} \
      --per_gpu_eval_batch_size ${PER_GPU_VAL_BSZ} \
      --gradient_accumulation_steps ${GRAD_ACCU_STEPS} \
      --max_steps ${MAX_STEPS} \
      --warmup_steps ${WARMUP_STEPS} \
      --learning_rate ${LEARNING_RATE} \
      --logging_steps ${LOGGING_STEPS} \
      --save_steps ${SAVE_STEPS} \
      |& tee ${MODEL_DIR}/log.txt
  done
done
