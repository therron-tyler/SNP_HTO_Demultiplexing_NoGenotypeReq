#!/bin/bash
#SBATCH -A alloc
#SBATCH -p genomics
#SBATCH -t 40:00:00
#SBATCH --mail-type=ALL
#SBATCH --mail-user=email
#SBATCH --output=%x.%j.out
#SBATCH --mem=60gb
#SBATCH --job-name=snp
#SBATCH -N 1
#SBATCH -n 12

sample=sample
cat $(ls -1 ${sample}_L*_R1_001.fastq.gz | sort -V) > ${sample}_R1.fastq.gz
cat $(ls -1 ${sample}_L*_R2_001.fastq.gz | sort -V) > ${sample}_R2.fastq.gz

echo "R1 merged lines:" $(gzip -cd sample_S1_R1.fastq.gz | wc -l)
echo "R2 merged lines:" $(gzip -cd sample_S1_R2.fastq.gz | wc -l)

