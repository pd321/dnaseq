Paired end sequencing reads were aligned to the human reference genome(hg19) using bwa mem. Picard was subsequently used to mark PCR duplicates. Systematic errors in base quality scores were then corrected for using GATK4 BaseRecalibrator.

Somatic single nucleotide variants and short indels were detected against a matched normal using GATK4 Mutect2. The variants calls from Mutect2 were further filtered with GATK4 FilterMutectCalls.
