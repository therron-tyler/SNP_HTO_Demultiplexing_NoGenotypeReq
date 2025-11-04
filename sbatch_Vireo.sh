#!/bin/bash
#SBATCH -A alloc
#SBATCH -p genomics
#SBATCH -t 40:00:00
#SBATCH --mail-type=ALL
#SBATCH --mail-user=email
#SBATCH --output=%x.%j.out
#SBATCH --mem=60gb
#SBATCH --job-name=vireo
#SBATCH -N 1
#SBATCH -n 14

if command -v mamba >/dev/null 2>&1; then
  eval "$(mamba shell hook --shell bash)"
  mamba activate vireo_env
else
  eval "$($(command -v conda) shell.bash hook)"
  conda activate vireo_env
fi

WORK_DIR=/work_dir

bash SNPdemux_Vireo_v1.sh \
  --sample sample \
  --bam "${WORK_DIR}/possorted_genome_bam.bam" \
  --barcodes "${WORK_DIR}/barcodes.tsv" \
  --outdir "${WORK_DIR}" \
  --n-donor 4 \
  --threads 14
