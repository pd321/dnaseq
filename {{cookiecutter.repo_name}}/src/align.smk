rule trimgalore:
	input:
		get_fastq
	output:
		r1 = temp("results/bam/{sample}_R1_val_1.fq.gz"),
		r2 = temp("results/bam/{sample}_R2_val_2.fq.gz")
	conda:
		"envs/trimgalore.yaml"
	log:
		"logs/trimgalore/{sample}.log"
	params:
		quality = config['trimgalore']['quality'],
		stringency = config['trimgalore']['stringency'],
		e = config['trimgalore']['e']
	threads: threads_mid if threads_mid < 4 else 4
	shell:
		'trim_galore '
		'--quality {params.quality} '
		'--stringency {params.stringency} '
		'-e {params.e} '
		'--gzip '
		'--output_dir results/bam/ '
		'--cores {threads} '
		'--basename {wildcards.sample} '
		'--paired --no_report_file '
		'{input[0]} {input[1]} 2>&1 | tee {log}'

rule bwa:
	input:
		r1 = rules.trimgalore.output.r1,
		r2 = rules.trimgalore.output.r2
	output:
		temp("results/bam/{sample}_bwa.bam")
	conda:
		"envs/bwa.yaml"
	log:
		"logs/bwa/{sample}.log"
	threads: threads_mid
	params:
		bwaindex = config['bwa']['bwaindex']
	shell:
		'bwa mem '
		'-t {threads} '
		'-M -R \'@RG\\tID:{wildcards.sample}\\tSM:{wildcards.sample}\\tLB:{wildcards.sample}\\tPL:illumina\' '
		'{params.bwaindex} {input.r1} {input.r2} 2> {log} '
		'| samtools sort -@ {threads} -o {output}'

rule mark_duplicates:
	input:
		rules.bwa.output
	output:
		bam=temp("results/bam/{sample}_mrkdup.bam"),
		bai=temp("results/bam/{sample}_mrkdup.bai"),
		metrics="results/qc/picard/dedup/{sample}.metrics.txt"
	conda:
		"envs/picard.yaml"
	log:
		"logs/picard/dedup/{sample}.log"
	shell:
		'picard MarkDuplicates '
		'CREATE_INDEX=true '
		'INPUT={input} '
		'OUTPUT={output.bam} '
		'METRICS_FILE={output.metrics} 2>&1 | tee {log}'

rule baserecalibrator:
	input:
		bam = rules.mark_duplicates.output.bam,
		bai = rules.mark_duplicates.output.bai
	output:
		"results/qc/baserecalibrator/{sample}_recal_data.table"
	conda:
		"envs/gatk4.yaml"
	log:
		"logs/gatk/baserecalibrator/{sample}.log"
	params:
		reference = config['general']['reference'],
		intervals = config['general']['intervals'],
		knownsites = " ".join(map(lambda x:"--known-sites {}".format(x), config['gatk']['knownsites'].split(",")))
	shell:
		'gatk BaseRecalibrator '
		'--reference {params.reference} '
		'--input {input.bam} '
		'--output {output} '
		'--intervals {params.intervals} '
		'{params.knownsites} 2>&1 | tee {log}'

rule applybqsr:
	input:
		bam = rules.mark_duplicates.output.bam,
		bai = rules.mark_duplicates.output.bai,
		recal_table = rules.baserecalibrator.output
	output:
		"results/bam/{sample}_recal.bam"
	conda:
		"envs/gatk4.yaml"
	log:
		"logs/gatk/applybqsr/{sample}.log"
	params:
		reference = config['general']['reference'],
		intervals = config['general']['intervals']
	shell:
		'gatk ApplyBQSR '
		'--reference {params.reference} '
		'--input {input.bam} '
		'--output {output} '
		'--intervals {params.intervals} '
		'--bqsr-recal-file {input.recal_table} 2>&1 | tee {log}'
