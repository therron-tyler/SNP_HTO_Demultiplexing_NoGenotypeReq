#!/usr/bin/env bash

set -euo pipefail

FREEBAYES_PARALLEL="${FREEBAYES_PARALLEL:-freebayes-parallel}"
FASTA_GENERATE_REGIONS="${FASTA_GENERATE_REGIONS:-fasta_generate_regions.py}"
SCSPLIT_PYTHON="${SCSPLIT_PYTHON:-python}"

############################################
# minimal named-arg parser (only what you asked)
############################################
THREADS="${SLURM_CPUS_PER_TASK:-12}"
OUTDIR="."
SAMPLE="RS1"
BAM="possorted_genome_bam.bam"
DONORS=6

while [[ $# -gt 0 ]]; do
  case "$1" in
    --threads) THREADS="$2"; shift 2 ;;
    --outdir)  OUTDIR="$2";  shift 2 ;;
    --sample)  SAMPLE="$2";  shift 2 ;;
    --bam)     BAM="$2";     shift 2 ;;
    --donors)  DONORS="$2";  shift 2 ;;
    --barcodes) BARCODES="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 --sample NAME --bam BAM --outdir DIR --threads N --donors K"
      exit 0 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

# make outdir and work there
mkdir -p "$OUTDIR"
cd "$OUTDIR"

# let the rest of your script keep using these names/vars
export SLURM_CPUS_PER_TASK="$THREADS"
POS_SORT_BAM="$BAM"

############################################
# scSplit Workflow, with SAMPLE/BAM/THREADS/DONORS wired in
############################################

# filter bam
samtools view -S -b -q 10 -F 3844 "$BAM" > "${SAMPLE}_filtered.bam"

echo "sorting the bam because that is how freee bayes works the best"
# 2. Sort the BAM (freebayes works best on sorted input)
samtools sort -@ "$THREADS" -o "${SAMPLE}_filtered.sorted.bam" "${SAMPLE}_filtered.bam"

echo "indexing the bam"
# 3. Index the BAM
samtools index "${SAMPLE}_filtered.sorted.bam"

FILT_BAM="${SAMPLE}_filtered.sorted.bam"
echo "running freeebayes"


# already ran
"${FREEBAYES_PARALLEL}" <("${FASTA_GENERATE_REGIONS}" "${REF}.fai" 100000) \
  "${THREADS}" \
  -f "${REF}" \
  "${FILT_BAM}" > HTO_freebayes_parallel.vcf
echo "running bcftools filtering"

bcftools filter -i '%QUAL>30' HTO_freebayes_parallel.vcf > "${SAMPLE}_filtered_SNVs.vcf"

echo "running scSplit count"

"${SCSPLIT_PYTHON}" /home/ttm3567/63_tylert/Analysis_Algorithms/scSplit/scSplit count \
  -v "${SAMPLE}_filtered_SNVs.vcf" \
  -i "${SAMPLE}_filtered.sorted.bam" \
  -b "$BARCODES" \
  -c /home/ttm3567/63_tylert/Analysis_Algorithms/common_snvs_hg38_chr \
  -r "${SAMPLE}_ref_filtered.csv" \
  -a "${SAMPLE}_alt_filtered.csv" \
  -o "$OUTDIR"

echo "running scSplit run"

RESULT_DIR="${OUTDIR}/${SAMPLE}_scSplit_Results"
mkdir -p "$RESULT_DIR"

"${SCSPLIT_PYTHON}" /home/ttm3567/63_tylert/Analysis_Algorithms/scSplit/scSplit run \
  -r "${SAMPLE}_ref_filtered.csv" \
  -a "${SAMPLE}_alt_filtered.csv" \
  -n "$DONORS" \
  -o "$RESULT_DIR" 

echo "running scSplit genotype"

"${SCSPLIT_PYTHON}" /home/ttm3567/63_tylert/Analysis_Algorithms/scSplit/scSplit genotype \
  -r "${SAMPLE}_ref_filtered.csv" \
  -a "${SAMPLE}_alt_filtered.csv" \
  -p "${RESULT_DIR}/scSplit_P_s_c.csv" \
  -o "$RESULT_DIR"

echo "done"
