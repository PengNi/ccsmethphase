#! /usr/bin/python
import argparse
import os


def str2bool(v):
    # susendberg's function
    return v.lower() in ("yes", "true", "t", "1")


def get_mposinfo(posinfofile):  # bed
    mposinfo = []
    with open(posinfofile, 'r') as rf:
        for line in rf:
            words = line.strip().split('\t')
            chrom, pos, strand, coverage = words[0], int(words[1]), words[5], int(words[9])
            rmet = int(words[10]) / float(100)
            mposinfo.append((chrom, pos, strand, coverage, rmet))
    return mposinfo


def get_high_confidence_positions(mpositions, prmet_lb, nrmet_ub, coverage_lb, coverage_ub, onlychr):
    hcposes_pos = []
    hcposes_neg = []

    if not onlychr:
        for mpos in mpositions:
            coverage_tmp, crmet_tmp = mpos[3], mpos[4]
            if coverage_lb <= coverage_tmp <= coverage_ub:
                if prmet_lb <= crmet_tmp:
                    hcposes_pos.append(mpos)
                elif nrmet_ub >= crmet_tmp:
                    hcposes_neg.append(mpos)
    else:
        for mpos in mpositions:
            chrom_tmp = mpos[0]
            coverage_tmp, crmet_tmp = mpos[3], mpos[4]
            if (chrom_tmp.lower().startswith('chr')
                    and coverage_lb <= coverage_tmp <= coverage_ub):
                if prmet_lb <= crmet_tmp:
                    hcposes_pos.append(mpos)
                elif nrmet_ub >= crmet_tmp:
                    hcposes_neg.append(mpos)
    return hcposes_pos, hcposes_neg


def write_posinfo(posinfo, mcfile):
    with open(mcfile, 'w') as wf:
        # wf.write('\t'.join(['chromosome', 'pos', 'strand', 'coverage', 'Rmet']) + '\n')
        for mctmp in posinfo:
            wf.write('\t'.join(list(map(str, list(mctmp)))) + '\n')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--posinfo_fp', type=str, default='', required=True,
                        help='bedmethyl format, .bed')
    parser.add_argument('--prmet', type=float, default=1.0, required=False,
                        help="positive positions rmet cut off")
    parser.add_argument('--nrmet', type=float, default=0.0, required=False,
                        help="negative positions rmet cut off")
    parser.add_argument('--coverage_lb', type=int, default=5, required=False,
                        help="coverage lower bound")
    parser.add_argument('--coverage_ub', type=int, default=50000, required=False,
                        help="coverage upper bound")
    parser.add_argument('--is_only_chr', type=str, default='no', required=False,
                        help="is only choose chr* for high-confidence positions, for human genome")
    parser.add_argument('--wfile_pos', type=str, required=False, default=None)
    parser.add_argument('--wfile_neg', type=str, required=False, default=None)

    argv = parser.parse_args()
    posinfo_fp = argv.posinfo_fp
    prmet = argv.prmet
    nrmet = argv.nrmet
    coverage_lb = argv.coverage_lb
    coverage_ub = argv.coverage_ub
    only_chr = str2bool(argv.is_only_chr)

    mposinfo = get_mposinfo(posinfo_fp)
    phcposes, nhcposes = get_high_confidence_positions(mposinfo, prmet, nrmet, coverage_lb, coverage_ub, only_chr)

    fname, fext = os.path.splitext(posinfo_fp)
    paras_str = '.cov_' + str(coverage_lb) + '_' + str(coverage_ub)
    if only_chr:
        paras_str += '.chr'
    hcp_filename = fname + '.rmet_' + str(prmet) + paras_str + '.hcpos_pos' + fext if argv.wfile_pos is None else argv.wfile_pos
    hcn_filename = fname + '.rmet_' + str(nrmet) + paras_str + '.hcpos_neg' + fext if argv.wfile_neg is None else argv.wfile_neg

    write_posinfo(phcposes, hcp_filename)
    write_posinfo(nhcposes, hcn_filename)


if __name__ == '__main__':
    main()
