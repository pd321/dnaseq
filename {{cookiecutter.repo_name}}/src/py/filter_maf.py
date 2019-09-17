"""
Script to filter given maf file based on supplied arguments.
"""

import argparse
import csv
import logging
import os


class MAFMutation(object):

    def __init__(self, maf_dict):
        """
        :param maf_dict: Dict of a maf row
        """
        self.maf_dict = maf_dict
        self.vaf = 0
        self.keep = True

    def calculate_vaf(self):
        """
        Calculate VAF from alt allle count and depth
        :return: None
        """
        try:
            self.vaf = int(self.maf_dict['t_alt_count']) / int(self.maf_dict['t_depth'])
        except ZeroDivisionError:
            self.vaf = 0
        self.maf_dict['VAF'] = self.vaf

    def filt_vaf(self, vaf_cutoff):
        """
        Remove variants below given variant allele frequency
        :param vaf_cutoff: Cutoff value for VAF
        :return: None
        """
        if self.vaf < vaf_cutoff:
            self.keep = False

    def filt_pass(self):
        """
        Remove variants which are not marked as PASS by the variant caller
        :return: None
        """
        if self.maf_dict['FILTER'] != "PASS":
            self.keep = False


def main(args):
    with open(args.maf) as maf_handle, open(args.out, "w") as maf_out:
        # Remove the version line from maf
        maf_handle.readline()

        maf_dicts = csv.DictReader(maf_handle, delimiter="\t")

        # Setup the output file
        out_fieldnames = maf_dicts.fieldnames + ["VAF"]
        writer = csv.DictWriter(maf_out, fieldnames=out_fieldnames, delimiter="\t")
        writer.writeheader()

        for maf_dict in maf_dicts:

            maf_mutation = MAFMutation(maf_dict)
            maf_mutation.calculate_vaf()
            maf_mutation.filt_vaf(args.vaf_cutoff)

            if args.pass_filt:
                maf_mutation.filt_pass()

            if maf_mutation.keep:
                writer.writerow(maf_mutation.maf_dict)


if __name__ == '__main__':

    logging.basicConfig(format='%(asctime)s %(levelname)s : %(message)s', level=logging.INFO)

    def is_valid_file(parser, arg):
        """ Check if file exists """
        if not os.path.isfile(arg):
            parser.error('The file at %s does not exist' % arg)
        else:
            return arg

    epilog = "EXAMPLE: python " + os.path.basename(__file__) + \
             " --maf /path/to/input.maf --out /path/to/filt.maf " \
             "--keep_only_pass --vaf 0.05"

    parser = argparse.ArgumentParser(description="Script to filter given maf file",
                                     epilog=epilog)

    required_args_group = parser.add_argument_group('required arguments')
    required_args_group.add_argument('-i', '--maf', dest='maf', required=True, help="Input MAF",
                                     type=lambda x: is_valid_file(parser, x))
    required_args_group.add_argument('-o', '--out', dest='out', help="Output MAF")
    parser.add_argument('-p', '--pass_filt', dest='pass_filt', action='store_true', help="Keep only passed vars")
    parser.add_argument('-v', '--vaf_cutoff', dest='vaf_cutoff', default=0,
                        help="Keep vars with VAF above given value (default: %(default)s)")

    args = parser.parse_args()

    main(args)
