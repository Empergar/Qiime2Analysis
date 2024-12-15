#!/bin/bash

# Descargar y crear entorno QIIME2
wget https://data.qiime2.org/distro/amplicon/qiime2-amplicon-2023.9-py38-osx-conda.yml
conda env create -n qiime2-amplicon-2023.9 --file qiime2-amplicon-2023.9-py38-osx-conda.yml

# Activar entorno de QIIME2
conda activate qiime2-amplicon-2023.9

# Crear directorio de trabajo
mkdir -p qiime2-atacama-tutorial/emp-paired-end-sequences
cd qiime2-atacama-tutorial

# Descargar metadatos y secuencias
wget -O sample-metadata.tsv "https://data.qiime2.org/2023.5/tutorials/atacama-soils/sample_metadata.tsv"
wget -O emp-paired-end-sequences/forward.fastq.gz "https://data.qiime2.org/2023.5/tutorials/atacama-soils/10p/forward.fastq.gz"
wget -O emp-paired-end-sequences/reverse.fastq.gz "https://data.qiime2.org/2023.5/tutorials/atacama-soils/10p/reverse.fastq.gz"
wget -O emp-paired-end-sequences/barcodes.fastq.gz "https://data.qiime2.org/2023.5/tutorials/atacama-soils/10p/barcodes.fastq.gz"

# Importar datos a QIIME2
qiime tools import \
  --type EMPPairedEndSequences \
  --input-path emp-paired-end-sequences \
  --output-path emp-paired-end-sequences.qza

# Demultiplexar datos
qiime demux emp-paired \
  --m-barcodes-file sample-metadata.tsv \
  --m-barcodes-column barcode-sequence \
  --p-rev-comp-mapping-barcodes \
  --i-seqs emp-paired-end-sequences.qza \
  --o-per-sample-sequences demux-full.qza \
  --o-error-correction-details demux-details.qza

# Submuestrear datos
qiime demux subsample-paired \
  --i-sequences demux-full.qza \
  --p-fraction 0.3 \
  --o-subsampled-sequences demux-subsample.qza

# Generar visualización de datos submuestreados
qiime demux summarize \
  --i-data demux-subsample.qza \
  --o-visualization demux-subsample.qzv

# Exportar datos para filtrar muestras con baja cobertura
qiime tools export \
  --input-path demux-subsample.qzv \
  --output-path demux-subsample/

# Filtrar muestras con menos de 100 lecturas
qiime demux filter-samples \
  --i-demux demux-subsample.qza \
  --m-metadata-file demux-subsample/per-sample-fastq-counts.tsv \
  --p-where 'CAST([forward sequence count] AS INT) > 100' \
  --o-filtered-demux demux.qza

# Denoising con DADA2
qiime dada2 denoise-paired \
  --i-demultiplexed-seqs demux.qza \
  --p-trim-left-f 13 --p-trim-left-r 13 \
  --p-trunc-len-f 150 --p-trunc-len-r 150 \
  --o-table table.qza \
  --o-representative-sequences rep-seqs.qza \
  --o-denoising-stats denoising-stats.qza

# Generar visualización de tabla
qiime feature-table summarize \
  --i-table table.qza \
  --o-visualization table.qzv \
  --m-sample-metadata-file sample-metadata.tsv

# Generar árbol filogenético
qiime phylogeny align-to-tree-mafft-fasttree \
  --i-sequences rep-seqs.qza \
  --o-alignment aligned-rep-seqs.qza \
  --o-masked-alignment masked-aligned-rep-seqs.qza \
  --o-tree unrooted-tree.qza \
  --o-rooted-tree rooted-tree.qza

# Calcular diversidad alfa y beta
qiime diversity core-metrics-phylogenetic \
  --i-phylogeny rooted-tree.qza \
  --i-table table.qza \
  --p-sampling-depth 854 \
  --m-metadata-file sample-metadata.tsv \
  --output-dir core-metrics-results

# Descargar clasificador taxonómico Greengenes
wget -O gg-13-8-99-515-806-nb-classifier.qza "https://data.qiime2.org/2023.5/common/gg-13-8-99-515-806-nb-classifier.qza"

# Clasificar taxonomía
qiime feature-classifier classify-sklearn \
  --i-classifier gg-13-8-99-515-806-nb-classifier.qza \
  --i-reads rep-seqs.qza \
  --o-classification taxonomy.qza

# Generar visualización de taxonomía
qiime metadata tabulate \
  --m-input-file taxonomy.qza \
  --o-visualization taxonomy.qzv

# Análisis diferencial con ANCOM
qiime composition add-pseudocount \
  --i-table table.qza \
  --o-composition-table comp-table.qza

qiime composition ancom \
  --i-table comp-table.qza \
  --m-metadata-file sample-metadata.tsv \
  --m-metadata-column extract-group-no \
  --o-visualization ancom-extract-group-no.qzv

# Finalizar entorno
conda deactivate

echo "Análisis completado. Revisa los archivos generados."
