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

with open("charges.csv") as f :
    unbucketed_crimes = set()

    reader = csv.reader(f)
    reader.next()

    statute_counter = defaultdict(int)
    statute_descriptions = defaultdict(list)

    for row in reader :
        original_statute = cleanStatute(row[3])
        statute_counter[original_statute] += 1

        statute_descriptions[original_statute].append(row[4]) 

        amended_statute = row[9]
        if amended_statute :
            amended_statute = cleanStatute(amended_statute)
            statute_counter[amended_statute] += 1

            statute_descriptions[amended_statute].append(row[10]) 

with open("ilcs.csv", "w") as f :
    writer = csv.writer(f)
    writer.writerow(["Statute", "Desc", "Count"])

    for sec, count in sorted(statute_counter.items(), key=lambda x : -x[1]) :
        common_desc = Counter(statute_descriptions[sec]).most_common(1)[0][0]
        writer.writerow([sec, common_desc, count])



