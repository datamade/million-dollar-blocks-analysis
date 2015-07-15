#!/usr/bin/python
# -*- coding: utf-8 -*-

import csv
from collections import defaultdict, Counter
import pprint

import statute


def cleanStatute(x) :
    try :
        return statute.format_statute(statute.parse_statute(x))
    except (statute.ILCSLookupError, statute.StatuteFormatError) :
        print x
        return x

charge_type = {}
with open('ilcs.coded.csv') as f :
    reader = csv.DictReader(f)
    for row in reader :
        charge_type[row['Statute']] = row['Code']

with open("charges.csv") as rf, open('categorized_charges.csv', 'wb') as wf :
    charges = csv.reader(rf)
    categorized_charges = csv.writer(wf, lineterminator='\n')

    header = charges.next()
    header += ['clean_original_statute', 'original_charge_bin',
               'clean_amended_statute', 'amended_charge_bin']

    assert len(header) == 20
    categorized_charges.writerow(header)

    for row in charges :
        original_statute = cleanStatute(row[3])
        original_charge_type = charge_type.get(original_statute, None)

        amended_statute = cleanStatute(row[9])
        if amended_statute :
            amended_charge_type = charge_type.get(amended_statute, None)
        else :
            amended_charge_type = None

        row += [original_statute, original_charge_type,
                amended_statute, amended_charge_type]

        assert len(row) == 20

        categorized_charges.writerow(row)
