rule mutect2:
    input:
        tumor_bam = "results/bam/{tumor}_recal.bam",
        normal_bam = get_normal
    output:
        vcf = temp("results/vcf/{tumor}_raw.vcf"),
        vcf_idx = temp("results/vcf/{tumor}_raw.vcf.idx"),
        stats = temp("results/vcf/{tumor}_raw.vcf.stats"),
        f1r2 = "results/qc/gatk/orientation_bias/{tumor}.tar.gz"
    conda:
        "envs/gatk4.yaml"
    log:
        "logs/gatk/mutect2/{tumor}.log"
    threads: threads_low
    params:
        reference = config['general']['reference'],
        intervals = config['general']['intervals'],
        germline_resource = config['gatk']['germline_resource'],
        default_af = config['gatk']['default_af'],
        normal_sample_name = get_normal_name
    shell:
        'gatk Mutect2 '
        '--reference {params.reference} '
        '--input {input.tumor_bam} '
        '--input {input.normal_bam} '
        '--output {output.vcf} '
        '-normal {params.normal_sample_name} '
        '--intervals {params.intervals} '
        '--germline-resource {params.germline_resource} '
        '--f1r2-tar-gz {output.f1r2} '
        '--af-of-alleles-not-in-resource {params.default_af} 2>&1 | tee {log}'

rule learn_read_orientation:
    input:
        rules.mutect2.output.f1r2
    output:
        "results/qc/gatk/orientation_bias/{tumor}_ob_priors.tar.gz"
    conda:
        "envs/gatk4.yaml"
    log:
        "logs/gatk/learn_read_orientation/{tumor}.log"
    threads: threads_low
    shell:
        'gatk LearnReadOrientationModel -I {input} -O {output} 2>&1 | tee {log} '

rule filter_mutect_calls:
    input:
        vcf = rules.mutect2.output.vcf,
        vcf_idx = rules.mutect2.output.vcf_idx,
        stats = rules.mutect2.output.stats,
        ob_priors = rules.learn_read_orientation.output
    output:
        vcf = "results/vcf/{tumor}_filt.vcf",
        filt_stats = "results/qc/gatk/filter_mutect_calls/{tumor}_filt.vcf.filteringStats.tsv"
    conda:
        "envs/gatk4.yaml"
    log:
        "logs/gatk/filter_mutect_calls/{tumor}.log"
    threads: threads_low
    params:
        reference = config['general']['reference']
    shell:
        'gatk FilterMutectCalls '
        '--variant {input.vcf} '
        '--reference {params.reference} '
        '--filtering-stats {output.filt_stats} '
        '--ob-priors {input.ob_priors} '
        '--output {output.vcf} 2>&1 | tee {log} '

rule vcf2maf:
    input:
        rules.filter_mutect_calls.output.vcf
    output:
        maf = "results/maf/{tumor}.maf",
        vcf = temp("results/vcf/{tumor}_filt.vep.vcf")
    conda:
        "envs/vcf2maf.yaml"
    log:
        "logs/vcf2maf/{tumor}.log"
    threads: threads_mid
    params:
        normal_sample_name = get_normal_name,
        reference = config['general']['reference']
    shell:
        'vcf2maf.pl '
        '--input-vcf {input} '
        '--output-maf {output} '
        '--vep-forks {threads} '
        '--vcf-tumor-id {wildcards.tumor} '
        '--ref-fasta {params.reference} '
        '--filter-vcf 0 '
        '--vcf-normal-id {params.normal_sample_name} 2>&1 | tee {log}'
