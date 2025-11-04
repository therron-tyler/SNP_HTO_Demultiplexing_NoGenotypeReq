#!/bin/bash -l
#SBATCH -A b1042
#SBATCH -p genomics
#SBATCH -t 48:00:00
#SBATCH --mail-type=ALL
#SBATCH --mail-user=tyler.therron@northwestern.edu
#SBATCH --output=%x.%j.out
#SBATCH --mem=70gb
#SBATCH --job-name=SCplit
#SBATCH -N 1
#SBATCH -n 14

set -euo pipefail

# Optional: avoid the liblzma warnings from site libs
# unset LD_LIBRARY_PATH

module load samtools
module load bcftools

# Reference FASTA
export REF="/home/ttm3567/b1063/Reference/refdata-gex-GRCh38-2020-A/fasta/genome.fa"
[[ -f "${REF}.fai" ]] || samtools faidx "${REF}"

# Use the freebayes env binaries WITHOUT activating
ENV_FB="$HOME/.conda/envs/freebayes"
export FREEBAYES_PARALLEL="$ENV_FB/bin/freebayes-parallel"
export FASTA_GENERATE_REGIONS="$ENV_FB/bin/fasta_generate_regions.py"
export PATH="$ENV_FB/bin:$PATH"   # gives you parallel, vcflib tools, etc.

# scSplit python (your env)
export SCSPLIT_PYTHON="/projects/b1063/TylerT/ScSPLIT_III/bin/python"

# Quick sanity checks (optional but helpful)
which "$FREEBAYES_PARALLEL"; which "$FASTA_GENERATE_REGIONS"
which parallel; which vcffirstheader; which vcfstreamsort; which vcfuniq

WORK_DIR="/home/ttm3567/rootdir_scratch/20250930_RS1_SNP_decon/TEST_soup_or_cell_algo"

bash SC_Split_Pipeline_v1-1.sh \
  --sample RS1 \
  --bam "${WORK_DIR}/possorted_genome_bam.bam" \
  --outdir "${WORK_DIR}/RS1_scsplit" \
  --threads 14 \
  --donors 4 \
  --barcodes "${WORK_DIR}/RS1_barcodes.tsv"
