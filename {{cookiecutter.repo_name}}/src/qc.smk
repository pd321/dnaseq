rule fastqc:
	input:
		lambda wildcards: metadata_df.at[wildcards.sample, wildcards.group]
	output:
		html="results/qc/fastqc/{sample}_{group}_fastqc.html",
		zip="results/qc/fastqc/{sample}_{group}_fastqc.zip"
	threads: threads_low
	wrapper:
		"0.35.0/bio/fastqc"

rule samtools_flagstat:
	input:
		rules.applybqsr.output
	output:
		"results/qc/flagstat/{sample}.txt"
	conda:
		"envs/samtools.yaml"
	threads: threads_mid
	shell:
		'samtools flagstat -@ {threads} '
		'{input} > {output}'

rule multiqc:
	input:
		expand(["results/qc/fastqc/{sample}_{group}_fastqc.html", 
			"results/qc/picard/dedup/{sample}.metrics.txt", 
			"results/qc/flagstat/{sample}.txt"], group=["r1", "r2"], sample = samples)
	output:
		report("results/qc/multiqc/multiqc_report.html", caption="report/multiqc.rst", category="Quality control")
	conda:
		"envs/multiqc.yaml"
	threads: threads_high
	log:
		"logs/multiqc/multiqc.log"
	shell:
		'multiqc '
		'--force '
		'--outdir results/qc/multiqc '
		'--zip-data-dir . 2>&1 | tee {log}'
