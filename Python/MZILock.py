# -*- coding: utf-8 -*-
"""
by JD Deschenes, 2016

"""
import sys
from PyQt4 import QtGui, Qt, QtCore
import numpy as np

from win32gui import SetWindowPos
import win32con

import winsound

from initialConfiguration import initialConfiguration
from RedPitayaDevice import RedPitayaDevice

import time
import socket


def main():

    # Specify the mapping between the MAC addresses (which are used as a form of serial numbers) and the box data
    devices_data = {}
    devices_data['00:26:32:f0:16:dc'] = {'color': '#1CC981',
                        'name': 'Red Pitaya 1',
                        'shorthand': 'RP 1',
                        'config file': 'system_parameters_RP_1.xml',
                        #'port': 60002
                        }

    dev = RedPitayaDevice()

    ###########################################################################
    # Start the User Interface
    
    app = QtGui.QApplication(sys.argv)
    
    strBroadcastAddress = '192.168.0.255'
    strFPGAFirmware=r'..\FPGA\bitfiles\red_pitaya_top.bit'
    strCPUFirmware=r'..\Zynq\monitor-tcp\monitor-tcp'
    initial_config = initialConfiguration(dev, devices_data, strBroadcastAddress, strFPGAFirmware, strCPUFirmware)
    
    app.exec_()
    
    if initial_config.bOk == False:
        # User clicked cancel. simply close the program:
        return
    
    dev.OpenTCPConnection(initial_config.strSelectedIP)

    dev.write_Zynq_register_int32(0x00030, 1)
    #for i in range(1024):
    #    dev.write_Zynq_register_int32(i*4,i)
    #rp.write_Zynq_register_int32(0x00000,143246)
    #rp.write_Zynq_register_int32(0x00FFC,143246)
    #ret = rp.read_Zynq_register_int32(0x00FFC)
    ret = dev.read_Zynq_buffer_int16(0x01000, 1024)
    print(ret)
    
    dev.CloseTCPConnection()

    # # connect to the selected RedPitaya
    # sl.dev.OpenTCPConnection(initial_config.strSelectedIP)
    # sl.initSubModules(initial_config.bSendDefaultValues)


    

if __name__ == '__main__':
    main()     
    
    