#!/usr/bin/env python3
import re
import argparse
from pathlib import Path
from numpy.random import default_rng

# Define regular expressions to search for in PDI, SDI and DO test vector files
instructionPattern = re.compile('(INS = )([0-9A-F]+)')
headerPattern = re.compile('(HDR = )([0-9A-F]+)')
dataPattern = re.compile('(DAT = )([0-9A-F]+)')
statusPattern = re.compile('(STT = )([0-9A-F]+)')
tvNumPattern = re.compile('(#### MsgID=)( )+([0-9A-F]+)')

format_array = ['02X', '04X', '06X', '08X']
zero_fill_array = ['00', '0000', '000000', '00000000']

# Initialize random number generator
rng = default_rng()


# Define function for parsing data from test vector file and creating shared file
def gen_shared_tv_file(in_file, out_file, num_shares, fixed_bool):

    # Initialize masks
    masks = []
    for share_num in range(0, num_shares - 1):
        masks.append(0)

    # Create random masks for first test vector, use these in the case of fixed mode
    for share_num in range(0, num_shares - 1):
        masks[share_num] = (rng.integers(1, (2 ** args.iow - 1)))

    tvFile = open(in_file, "r")
    hex_index = int(args.iow / 4)  # Number of hex chars required to obtain PW

    out_file.write("-"*80 + "\n")
    out_file.write("File Information:\n")
    out_file.write(str(num_shares) + " share version of \'" + in_file + "\' with IOW = " + str(args.iow) + ".\n")

    # If running in fixed mode, output the fixed random masks
    if fixed_bool:
        out_file.write("FIXED mask values are: ")
        for maskIndex in range(0, len(masks)):
            out_file.write(format(masks[maskIndex], format_array[int(args.iow / 8) - 1]) + " ")
        out_file.write("\n")

    out_file.write("-"*80 + "\n\n")

    # Output number of shares for TB to read in
    out_file.write("NUM = " + str(num_shares) + "\n")

    for line in tvFile:
        insMatch = re.search(instructionPattern, line)
        hdrMatch = re.search(headerPattern, line)
        datMatch = re.search(dataPattern, line)
        sttMatch = re.search(statusPattern, line)
        tvNumMatch = re.search(tvNumPattern, line)

        # Output number of current TV
        if tvNumMatch:
            current_tv = tvNumMatch.group(3)
            out_file.write("\nTV: " + current_tv + " \n")

            # Update the random masks for each test vector
            if int(current_tv) != 1 and not fixed_bool:
                for share_num in range(0, num_shares - 1):
                    masks[share_num] = (rng.integers(1, (2 ** args.iow - 1)))

        # Handle instruction output
        if insMatch:
            insString = ''
            for i in range(0, num_shares):
                if i == 0:
                    insString = "INS = " + insMatch.group(2)
                else:
                    insString += zero_fill_array[int(args.iow/8) - 1]
            insString += "\n"
            out_file.write(insString)

        # Handle status output
        if sttMatch:
            out_file.write("STT = " + sttMatch.group(2) + "\n")

        # Store current segment header
        if hdrMatch:

            hdrString = ''
            for i in range(0, num_shares):
                if i == 0:
                    hdrString = "HDR = " + hdrMatch.group(2)
                else:
                    hdrString += "00000000"
            hdrString += "\n"
            out_file.write(hdrString)

        if datMatch:

            dataString = datMatch.group(2)

            # Reset data line string
            dat_line = ''

            # Store length of current line of file (number of hex chars)
            lineLen = int(len(dataString))

            # Loop until end of data line
            # Increment by number of hex characters required for PW (hex_index)
            for i in range(0, lineLen, hex_index):
                currentDatShared = ""
                for share in range(0, num_shares):
                    if share == 0:
                        dat_share = format(int(str(dataString[i:i + hex_index]), 16) ^ masks[share], format_array[int(args.iow/8) - 1])
                    elif share <= len(masks)-1:
                        dat_share = format(masks[share-1] ^ masks[share], format_array[int(args.iow/8) - 1])
                    else:
                        dat_share = format(masks[share - 1], format_array[int(args.iow/8) - 1])
                    currentDatShared = currentDatShared + dat_share
                dat_line = dat_line + currentDatShared

            out_file.write("DAT = " + dat_line + "\n")

    out_file.write("\n###EOF\n")    # Append end of file to output file
    tvFile.close()                  # Close test vector file


# Setup command line argument parsing
parser = argparse.ArgumentParser(description='Script parses existing cryptotvgen test vectors and creates shared versions.', formatter_class=argparse.ArgumentDefaultsHelpFormatter)
parser.add_argument('-iow', type=int, help='I/O Width.', required=True, choices={8, 16, 32})
parser.add_argument('-dest', type=str, help='Name of destination folder for shared tv files.', required=False, default=".")
parser.add_argument('-path', type=str, help='Path to existing test vectors.', required=False, default=".")
parser.add_argument('-num', type=int, help='Number of shares to create.', required=True, choices=range(2, 5))
parser.add_argument('-pdi', type=str, help='Name of input PDI file.', required=False, default="pdi.txt")
parser.add_argument('-sdi', type=str, help='Name of input SDI file.', required=False, default="sdi.txt")
parser.add_argument('-fixed', type=bool, help='Method of creating shared test vectors: '
                                              'Select True for fixed mask values across all PDI TVs and fixed mask values across all SDI TVs. '
                                              'Defaults to False, with every TV having a new random mask.', required=False, default=False)
args = parser.parse_args()

# Check for the existence of input PDI and SDI files
validInput = True
if not Path(args.path + "/" + args.pdi).exists():
    print("ERROR: PDI file at path \'" + args.path + "\' does not exist. Please use a valid input path.")
    validInput = False

if not Path(args.path + "/" + args.sdi).exists():
    print("ERROR: SDI file at path \'" + args.path + "\' does not exist. Please use a valid input path.")
    validInput = False

if not validInput:
    exit()

# Provide terminal output
print("Generating " + str(args.num) + " share boolean masked PDI & SDI test vector files.")
print("Results stored in sharedPDI.txt and sharedSDI.txt in the \'" + args.dest + "\' directory.\n")

# Open the output files to write to
if not Path(args.dest).exists():
    Path(args.dest).mkdir()

outputFileP = open(args.dest + "/sharedPDI.txt", "w")
outputFileS = open(args.dest + "/sharedSDI.txt", "w")

# Parse the existing PDI & SDI test vector files and generate shared versions
gen_shared_tv_file(args.path + "/" + args.pdi, outputFileP, args.num, args.fixed)
gen_shared_tv_file(args.path + "/" + args.sdi, outputFileS, args.num, args.fixed)

# Close the output files
outputFileP.close()
outputFileS.close()
