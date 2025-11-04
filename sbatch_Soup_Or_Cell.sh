#!/bin/bash
#SBATCH -A alloc
#SBATCH -p genomics
#SBATCH -t 48:00:00
#SBATCH --mail-type=ALL
#SBATCH --mail-user=email
#SBATCH --output=%x.%j.out
#SBATCH --mem=90gb
#SBATCH --job-name=single
#SBATCH -N 1
#SBATCH -n 14

module load singularity


singularity exec \
  --cleanenv \
  --bind /working_dir:/work \
  --bind /refdata-gex-GRCh38-2020-A/fasta:/ref \
  /singularity_download_location/souporcell_release.sif \
  bash -lc '
    set -euo pipefail
    cd /work
    mkdir -p SOUP_CELL_OUT
    /opt/souporcell/souporcell_pipeline.py \
      -i /work/possorted_genome_bam.bam \
      -b /work/RS1_barcodes.tsv \
      -f /ref/genome.fa \
      -t 14 \
      -o SOUP_CELL_OUT \
      -k 4
  '
