#!/usr/bin/env python3

import argparse
import sys
import socket
import random
import struct
import re

from scapy.all import sendp, send, srp1
from scapy.all import Packet, hexdump
from scapy.all import Ether, StrFixedLenField, XByteField, IntField
from scapy.all import bind_layers
import readline

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


def main():

    s = ''
    iface = 'eth0'

    while True:
        s = input('> ')
        if s == "quit":
            break
        print(s)
        try:
            i,ts = word_parser(s,0,[])
            pkt = Ether(dst='00:04:00:00:00:00', type=0x1234) / P4wordle(guess=ts[0])
            pkt = pkt/' '

            pkt.show()
            resp = srp1(pkt, iface=iface, timeout=1, verbose=False)
        except Exception as error:
            print(error)


if __name__ == '__main__':
    main()
