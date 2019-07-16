#!/usr/bin/env python3

import argparse
import glob
import logging
import os

import pandas as pd

def main(args):

    # Setup logging and print args
    logging.basicConfig(format='%(asctime)s %(levelname)s : %(message)s', level=logging.INFO)
    logging.info("Will include samples from the following dirs: {dirs}".format(dirs=",".join(args.sample_dirs)))
    logging.info("Read1 extension: {read1}".format(read1=args.read1_extension))
    logging.info("Read2 extension: {read2}".format(read2=args.read2_extension))

    # Setup vars
    metadata = dict()
    read_info = dict()
    read_info['r1'] = args.read1_extension
    read_info['r2'] = args.read2_extension

    # Get files ending with extensions for each given dir
    for sample_dir in args.sample_dirs:
        for read_type in read_info.keys():
            files = glob.glob(sample_dir + '/**/*' + read_info[read_type], recursive=True)
            for file in files:
                sample_name = os.path.basename(os.path.dirname(file))
                metadata.setdefault(sample_name, {})
                logging.info("Will include {file} for "
                             "{sample_name}-{read_type}".format(file=file,sample_name=sample_name, read_type=read_type))
                metadata[sample_name][read_type] = file

    # Convert to df
    metadata_df = pd.DataFrame(metadata).transpose()

    # Add empty cols for Condition.
    # This is done to ensure naming consistency
    metadata_df['condition'] = ""
    metadata_df['matched_normal'] = ""

    # Write metadata file
    metadata_df.to_csv("metadata.tsv", sep="\t", index_label="sample_name")


if __name__ == "__main__":

    # Process command line args
    parser = argparse.ArgumentParser(description="Script to generate metadata.tsv")
    parser.add_argument('-d', '--dirs', dest='sample_dirs', action='append')

    # Choices restricted to prevent flip between read1/read2
    parser.add_argument('-f', '--read1', dest='read1_extension', default='_1.fq.gz',
                        choices=['_1.fq.gz', '_R1_001.fastq.gz'])
    parser.add_argument('-r', '--read2', dest='read2_extension', default='_2.fq.gz',
                        choices=['_2.fq.gz', '_R2_001.fastq.gz'])
    cmd_args = parser.parse_args()
    main(cmd_args)
