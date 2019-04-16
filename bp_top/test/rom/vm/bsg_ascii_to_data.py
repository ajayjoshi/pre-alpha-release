#!/usr/bin/python

import sys;
import os;
import binascii;

zero = 0;

myFile = open(sys.argv[1],"r");

i = 0;
all_zero = set("0_");
out = 0;
out_txt = "";
for line in myFile.readlines() :
    line = line.strip();
    if (len(line)!=0):
        if (line[0] != "#") :
            if (not zero or not (set(line) <= all_zero)) :
                digits_only = filter(lambda m:m.isdigit(), str(line));

                # http://stackoverflow.com/questions/2072351/python-conversion-from-binary-string-to-hexadecimal
                hstr = '%0*X' % ((len(digits_only) + 3) // 4, int(digits_only, 2))
                #if (out == 0) :
                #    out_txt = out_txt + hstr;
                #    out = 1;
                #else :
                size = len(hstr) / 16;
                for index in range(size) :
                    start = size - 1 - index;
                    print ".dword 0x" + hstr[start * 16 : start * 16 + 16];


