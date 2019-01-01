#!/usr/bin/python
'''
This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
'''

import sys
#import binascii

def hex_to_comma_list(hex_mask):
    binary = bin(int(hex_mask, 16))[2:]
    reversed_binary = binary[::-1]
    i = 0
    output = ""
    for bit in reversed_binary:
        if bit == '1':
            output = output + str(i) + ','
        i = i + 1
    return output[:-1]

def comma_list_to_hex(cpus):
    cpu_arr = cpus.split(",")
    binary_mask = 0
    for cpu in cpu_arr:
        binary_mask = binary_mask | (1 << int(cpu))
    return format(binary_mask, '02x')

if len(sys.argv) != 2:
    print "Please provide a hex CPU mask"
    sys.exit(2)

user_input = sys.argv[1]

try:
  print hex_to_comma_list(user_input)
except:
  print comma_list_to_hex(user_input)
