#!/usr/bin/env bash
set -Eeuo pipefail

############################################
# Defaults & env
############################################
THREADS="${SLURM_CPUS_PER_TASK:-12}"
SAMPLE=""
BAM=""
BARCODES=""
OUTDIR=""
SITES_VCF=""          # optional: bgzipped + tabixed sites VCF for GRCh38
NDONOR=""             # required
RAND_SEED=""          # optional
DOUBLET_RATE=""       # optional (vireo --doubletRate)

# cellsnp-lite defaults
CELLTAG="CB"
UMITAG="UB"
MIN_MAPQ=20
EXCL_FLAG=772
MIN_MAF=0.10
MIN_COUNT=100

# toggles
GZIP_OUT=1

############################################
# Helpers
############################################
log(){ echo "[$(date +'%F %T')] $*"; }
fail(){ echo "ERROR: $*" >&2; exit 1; }
need(){ command -v "$1" >/dev/null 2>&1 || fail "Missing dependency: $1"; }

usage(){
  cat <<'USAGE'
SNPdemux_Vireo.sh
Named-arg wrapper for cellsnp-lite + vireo.

Required:
  --bam PATH            Pos-sorted 10x BAM (e.g., possorted_genome_bam.bam)
  --barcodes PATH       10x barcodes.tsv (cell whitelist)
  --outdir DIR          Base output directory
  --n-donor INT         Number of donors expected by vireo

Optional:
  --sample NAME         Sample name (used in output folder names)
  --threads INT         Threads (default: $SLURM_CPUS_PER_TASK or 12)
  --sites-vcf PATH      Known SNP sites (bgzipped .vcf.gz + .tbi)
  --celltag TAG         BAM cell tag (default: CB)
  --umitag TAG          BAM UMI tag (default: UB)
  --min-mapq INT        Min MAPQ (default: 20)
  --excl-flag INT       Exclude FLAG mask (default: 772)
  --min-maf FLOAT       Min MAF for site inclusion (default: 0.10)
  --min-count INT       Min read count per site (default: 100)
  --no-gzip             Disable gzip compression of cellSNP outputs
  --rand-seed INT       vireo random seed
  --doublet-rate FLOAT  vireo prior doublet rate (e.g., 0.05)
  --help                Show this help

Notes:
- Output layout:
    <outdir>/<sample_or_auto>/cellSNP
    <outdir>/<sample_or_auto>/vireo
- If --sample is omitted, the script derives one from the BAM filename.
- --sites-vcf strongly recommended for speed/accuracy.
USAGE
  exit 0
}

############################################
# Parse args
############################################
while [[ $# -gt 0 ]]; do
  case "$1" in
    --sample)         SAMPLE="$2"; shift 2 ;;
    --bam)            BAM="$2"; shift 2 ;;
    --barcodes)       BARCODES="$2"; shift 2 ;;
    --outdir)         OUTDIR="$2"; shift 2 ;;
    --n-donor)        NDONOR="$2"; shift 2 ;;
    --threads)        THREADS="$2"; shift 2 ;;
    --sites-vcf)      SITES_VCF="$2"; shift 2 ;;
    --celltag)        CELLTAG="$2"; shift 2 ;;
    --umitag)         UMITAG="$2"; shift 2 ;;
    --min-mapq)       MIN_MAPQ="$2"; shift 2 ;;
    --excl-flag)      EXCL_FLAG="$2"; shift 2 ;;
    --min-maf)        MIN_MAF="$2"; shift 2 ;;
    --min-count)      MIN_COUNT="$2"; shift 2 ;;
    --no-gzip)        GZIP_OUT=0; shift ;;
    --rand-seed)      RAND_SEED="$2"; shift 2 ;;
    --doublet-rate)   DOUBLET_RATE="$2"; shift 2 ;;
    --help|-h)        usage ;;
    *) fail "Unknown arg: $1 (see --help)";;
  esac
done

############################################
# Validate inputs
############################################
[[ -z "$BAM"      ]] && fail "--bam is required"
[[ -z "$BARCODES" ]] && fail "--barcodes is required"
[[ -z "$OUTDIR"   ]] && fail "--outdir is required"
[[ -z "$NDONOR"   ]] && fail "--n-donor is required"

[[ -f "$BAM"      ]] || fail "BAM not found: $BAM"
[[ -f "$BARCODES" ]] || fail "barcodes.tsv not found: $BARCODES"
[[ -n "$SAMPLE"   ]] || SAMPLE="$(basename "$BAM" | sed 's/\..*//')"

# If provided, sites VCF must be bgzipped + tabixed
if [[ -n "$SITES_VCF" ]]; then
  [[ -f "$SITES_VCF" ]] || fail "sites VCF not found: $SITES_VCF"
  [[ -f "${SITES_VCF}.tbi" || -f "${SITES_VCF%.gz}.tbi" ]] || fail "sites VCF missing .tbi index (tabix): $SITES_VCF"
fi

# deps
need cellsnp-lite
need vireo

# Optional deps only if we need to gunzip/gzip/index later (not required here)
if [[ -n "$SITES_VCF" ]]; then
  need tabix
fi

############################################
# Output dirs
############################################
BASE_OUT="${OUTDIR%/}/${SAMPLE}_SNPdemux"
OUT_CELLSNP="${BASE_OUT}/cellSNP"
OUT_VIREO="${BASE_OUT}/vireo"
mkdir -p "$OUT_CELLSNP" "$OUT_VIREO"

log "Sample         : $SAMPLE"
log "BAM            : $BAM"
log "Barcodes       : $BARCODES"
log "Threads        : $THREADS"
log "Sites VCF      : ${SITES_VCF:-<none>}"
log "cellsnp out    : $OUT_CELLSNP"
log "vireo out      : $OUT_VIREO"
log "nDonor         : $NDONOR"

############################################
# Run cellsnp-lite
############################################
CELL_GZIP_FLAG=()
[[ "$GZIP_OUT" -eq 1 ]] && CELL_GZIP_FLAG=(--gzip)

CELL_SITES_FLAG=()
[[ -n "$SITES_VCF" ]] && CELL_SITES_FLAG=(-R "$SITES_VCF")

log "Running cellsnp-lite…"
cellsnp-lite \
  -s "$BAM" \
  -b "$BARCODES" \
  -O "$OUT_CELLSNP" \
  -p "$THREADS" \
  --cellTAG "$CELLTAG" \
  --UMItag "$UMITAG" \
  --minMAPQ "$MIN_MAPQ" \
  --exclFLAG "$EXCL_FLAG" \
  --minMAF "$MIN_MAF" \
  --minCOUNT "$MIN_COUNT" \
  "${CELL_GZIP_FLAG[@]}" \
  "${CELL_SITES_FLAG[@]}"

############################################
# Run vireo
############################################
VIREO_ARGS=( --cellData "$OUT_CELLSNP" --nDonor "$NDONOR" --outDir "$OUT_VIREO" )
[[ -n "$RAND_SEED"    ]] && VIREO_ARGS+=( --randSeed "$RAND_SEED" )
[[ -n "$DOUBLET_RATE" ]] && VIREO_ARGS+=( --doubletRate "$DOUBLET_RATE" )

log "Running vireo…"
vireo "${VIREO_ARGS[@]}"

log "Done. Outputs:"
log "  cellSNP: $OUT_CELLSNP"
log "  vireo  : $OUT_VIREO"
