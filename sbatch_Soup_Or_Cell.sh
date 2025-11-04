#!/bin/bash
#SBATCH -A b1042
#SBATCH -p genomics
#SBATCH -t 48:00:00
#SBATCH --mail-type=ALL
#SBATCH --mail-user=tyler.therron@northwestern.edu
#SBATCH --output=%x.%j.out
#SBATCH --mem=90gb
#SBATCH --job-name=single
#SBATCH -N 1
#SBATCH -n 14

module load singularity


singularity exec \
  --cleanenv \
  --bind /home/ttm3567/rootdir_scratch/20250930_RS1_SNP_decon:/work \
  --bind /home/ttm3567/b1063/Reference/refdata-gex-GRCh38-2020-A/fasta:/ref \
  /home/ttm3567/63_tylert/Analysis_Algorithms/souporcell_release.sif \
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
