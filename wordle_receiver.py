#!/usr/bin/env python3

import argparse
import sys
import socket
import random
import struct
import re
from scapy.all import *
from scapy.all import sendp, send, srp1
from scapy.all import Packet, hexdump
from scapy.all import Ether, StrFixedLenField, XByteField, IntField
from scapy.all import bind_layers
import readline
import time
import os
from termcolor import colored

class P4wordle(Packet):
    name = "P4wordle"
    fields_desc = [ StrFixedLenField("wordle", "WORDLE", length=6),
                    StrFixedLenField("guess", "GUESS", length=5),
                    IntField("outcome", 0x0000)]

bind_layers(Ether, P4wordle, type=0x1234)

class WordParseError(Exception):
    pass

class Token:
    def __init__(self,type,value = None):
        self.type = type
        self.value = value

def word_parser(s, i, ts):
    pattern = "\s*^[A-Z]{5}\s*"
    match = re.match(pattern,s[i:])
    if match:
        ts.append(match.group())
        return i + match.end(), ts
    raise WordParseError("Expected An Upper Case 5 Letter Word")

def outcome(ans, x):
    os.system('color')

    #For some reason the int of the outcome is bitshifted to the left by 16 more spaces than expected
    #Note: Recieved bit stream is in the opposite direction of how the bits are defined in p4
    for i in range(5):
        exist = False
        right_place = False  
        if ((x&(1<<(23+2*i-1)))!=0): exist = True
        if ((x&(1<<(23+2*i)))!=0):right_place = True
        if (right_place):
            print(colored(chr(ans[i]), 'green'),end="")
        elif(exist):
            print(colored(chr(ans[i]), 'yellow'),end="")
        else:
            print(colored(chr(ans[i]), 'white'),end="")
    print()
def main():

    s = ''
    iface = 'eth0'

    while True:
        time.sleep(0.5)
        try:
            resp2 = sniff(filter = "ether dst 00:04:00:00:00:00", iface=iface,count = 2, timeout=10)
            resp = resp2[1]
            if resp:
                p4wordle=resp[P4wordle]
                print("This is p4wordle:",p4wordle)
                if p4wordle:
                    outcome(p4wordle.guess, p4wordle.outcome)
                else:
                    print("cannot find P4wordle header in the packet")
            else:
                print("Didn't receive response")
        except Exception as error:
            print(error)


if __name__ == '__main__':
    main()
