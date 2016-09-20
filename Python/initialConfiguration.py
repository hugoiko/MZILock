# -*- coding: utf-8 -*-
"""
Created on Fri Aug 26 00:26:50 2016

@author: JD
"""

import sys
from PyQt4 import QtGui, Qt
#import numpy as np
import UDPRedPitayaDiscovery

import time

import socket

class initialConfiguration(QtGui.QDialog):
    

        
    def __init__(self, dev, devices_data={}, strBroadcastAddress="192.168.2.255", strFPGAFirmware='', strCPUFirmware=''):
        super(initialConfiguration, self).__init__()
        
        # copy init parameters to member variables
        self.dev = dev
        self.strFPGAFirmware = strFPGAFirmware
        self.strCPUFirmware = strCPUFirmware
        self.devices_data = devices_data
        
        # we gather all RP data (IP, MAC, item index) tuples in this list:
        self.strSerialList = []
        
        
        # these are used as a form of "return values" of this dialog:
        self.bOk = False
        self.bSendDefaultValues = False
        self.strSelectedMAC = ''
        self.strSelectedIP = ''
        
        # create the UDP discovery object:
        self.udp_discovery = UDPRedPitayaDiscovery.UDPRedPitayaDiscovery(strBroadcastAddress)
        self.reset_list_and_send_broadcast()
        
        self.timerID = self.startTimer(int(100))
        
#        print 'before check_answers'
#        (strIP, strMAC) = self.udp_discovery.check_answers()
#        print 'after check_answers'

        
        # init the UI
        grid = Qt.QGridLayout()
        self.qlabel_serial = Qt.QLabel('Connected FPGAs')
        self.qlabel_broadcast = Qt.QLabel('UDP Broadcast address')
        self.qlabel_firmware = Qt.QLabel('FPGA Firmware file')
        self.qlabel_software = Qt.QLabel('CPU Software file')
        self.qcombo_serial = Qt.QComboBox()
        self.qcombo_serial.setMinimumContentsLength(100)    # I can't figure out how to make it scale correctly with content so we'll make it big enough...
        self.qcombo_serial.setSizeAdjustPolicy(Qt.QComboBox.AdjustToMinimumContentsLength)
        
        self.qedit_broadcast = Qt.QLineEdit(strBroadcastAddress)
        self.qedit_firmware = Qt.QLineEdit(self.strFPGAFirmware)
        self.qedit_software = Qt.QLineEdit(self.strCPUFirmware)
        
        self.qbtn_send_broadcast = Qt.QPushButton('Broadcast discovery packet')
        self.qbtn_reprogram_fpga = Qt.QPushButton('Update FPGA firmware')
        self.qbtn_reprogram_cpu = Qt.QPushButton('Update CPU software')
        self.qbtn_send_broadcast.clicked.connect(self.reset_list_and_send_broadcast)
        self.qbtn_reprogram_fpga.clicked.connect(self.programFPGAClicked)
        self.qbtn_reprogram_cpu.clicked.connect(self.programCPUClicked)
        
        self.qradio_reprogram = Qt.QRadioButton('Send default values')
        self.qradio_noreprogram = Qt.QRadioButton('Connect to an already running box (NOT WORKING YET)')
        self.qradio_reprogram.setChecked(True)
        
        self.qradio_noreprogram.setDisabled(True)
        
        btn_group = Qt.QButtonGroup(self)
        btn_group.addButton(self.qradio_reprogram)
        btn_group.setId(self.qradio_reprogram, 0)
        btn_group.addButton(self.qradio_noreprogram)
        btn_group.setId(self.qradio_noreprogram, 1)
        
        self.qbtn_yes = Qt.QPushButton('OK')
        self.qbtn_no = Qt.QPushButton('Cancel')
    
        self.qbtn_yes.clicked.connect(self.okClicked)
        self.qbtn_no.clicked.connect(self.cancelClicked)
        
        
        
        
#        btn_group2 = Qt.QButtonGroup(self)
#        btn_group2.addButton(self.qradio_clk_internal)
#        btn_group2.addButton(self.qradio_clk_external)
#        btn_group2.setId(self.qradio_clk_internal, 2)
#        btn_group2.setId(self.qradio_clk_external, 3)
#        self.close.connect(self.closeEvent)
        
        grid.addWidget(self.qlabel_serial, 0, 1)
        grid.addWidget(self.qcombo_serial, 0, 2)
        
        grid.addWidget(self.qbtn_send_broadcast, 1, 0)
        grid.addWidget(self.qlabel_broadcast, 1, 1)
        grid.addWidget(self.qedit_broadcast, 1, 2)
        
        grid.addWidget(self.qbtn_reprogram_fpga, 2, 0)
        grid.addWidget(self.qlabel_firmware, 2, 1)
        grid.addWidget(self.qedit_firmware, 2, 2)
        
        grid.addWidget(self.qbtn_reprogram_cpu, 3, 0)
        grid.addWidget(self.qlabel_software, 3, 1)
        grid.addWidget(self.qedit_software, 3, 2)
        
        
#        #FEATURE
#        grid.addWidget(self.qradio_reprogram, 4, 0)
#        grid.addWidget(self.qradio_noreprogram, 4, 1)
        
#        grid.addWidget(self.qradio_clk_internal, 3, 0)
#        grid.addWidget(self.qradio_clk_external, 3, 1)
        
#        grid.addWidget(self.qbtn_yes, 4, 0)
#        grid.addWidget(self.qbtn_no, 4, 1)
        hbox = Qt.QHBoxLayout()
        hbox.addStretch(1)
        hbox.addWidget(self.qbtn_yes)
        hbox.addWidget(self.qbtn_no)
        grid.addLayout(hbox, 5, 0, 1, 3)
        
        
        self.setLayout(grid)
        self.setWindowTitle('Initial configuration')
        self.qbtn_yes.setFocus()
        self.show()
        
    def reset_list_and_send_broadcast(self):
        # clear the list if it exists
        self.strSerialList
        try:
            self.qcombo_serial.clear()
            pass
        except AttributeError:
            pass
        
        # we need to reconnect the UDP discovery socket everytime we change our broadcast address
        try:
            self.udp_discovery.broadcast_address = self.qedit_broadcast.text()
            self.udp_discovery.connectClientSocket()
        except AttributeError:
            pass
        # send a broadcast packet to start building the list:
        self.udp_discovery.send_broadcast()
        
    def MAC_to_display_string(self, strMAC, strIP):
        # build the string that we will display to the user in the combo box:
        strDisplay = ''

        try:
            box_name = self.devices_data[strMAC]['name']
        except KeyError:
            box_name = ''
            pass
        
        try:
            box_color = self.devices_data[strMAC]['color']
        except KeyError:
            box_color = ''
            pass
        
        strDisplay = 'Name = %s, IP = %s, MAC = %s, Color = %s' % (box_name, strIP, strMAC, box_color)
        return strDisplay
        
    def timerEvent(self, e):
        # check if there are any answers to the broadcast packet
        (strIP, strMAC) = self.udp_discovery.check_answers()
#        print (strIP, strMAC)
        
        # iterate over answers
        while (strIP is not None):
            
            
            
            # build the string that we will display to the user in the combo box:
            strDisplay = self.MAC_to_display_string(strMAC, strIP)
            self.strSerialList.append((strIP, strMAC))
            self.qcombo_serial.addItem(strDisplay)
#            print self.qcombo_serial.sizeAdjustPolicy()
#            print self.qcombo_serial.minimumSizeHint()
            
            # for the next iteration:
            # check if there are any answers to the broadcast packet
            (strIP, strMAC) = self.udp_discovery.check_answers()
            
            time.sleep(0.1)
        
    def okClicked(self):
        self.bOk = True

        self.strFPGAFirmware = (self.qedit_firmware.text())  # the str() is to convert the QString to a normal Python string object
        self.strCPUFirmware  = (self.qedit_software.text())  # the str() is to convert the QString to a normal Python string object
        

        self.bSendDefaultValues  = self.qradio_reprogram.isChecked()
#        self.bExternalClock = self.qradio_clk_external.isChecked()
        try:
            (strIP, strMAC) = self.strSerialList[self.qcombo_serial.currentIndex()]
            self.strSelectedSerial = strMAC.replace(':', '') # this is just for legacy compatibility, when we had actual serial numbers
            self.strSelectedMAC = strMAC
            self.strSelectedIP = strIP
            
        except KeyError:
            # nothing bad happened, we probably simply had an empty list
            self.strSelectedSerial = ''
            pass

        # connect to the selected RedPitaya.
        self.dev.OpenTCPConnection(self.strSelectedIP)
        self.close()
        
    def programFPGAClicked(self):
        try:
            (strIP, strMAC) = self.strSerialList[self.qcombo_serial.currentIndex()]
            self.strSelectedMAC = strMAC
            self.strSelectedIP = strIP
        except KeyError:
            print "Error: no selected RedPitaya."
            return
        # connect to the selected RedPitaya, send new bitfile, then send programming command to the shell:
        self.dev.OpenTCPConnection(self.strSelectedIP)
        self.dev.write_file_on_remote(strFilenameLocal=str(self.qedit_firmware.text()), strFilenameRemote='/opt/red_pitaya_top.bit')
        self.dev.send_shell_command('cat /opt/red_pitaya_top.bit > /dev/xdevcfg')
        
        # disconnect:
        self.dev.sock.shutdown(socket.SHUT_RDWR)
        self.dev.sock.close()
        
        
    def programCPUClicked(self):
        try:
            (strIP, strMAC) = self.strSerialList[self.qcombo_serial.currentIndex()]
            self.strSelectedMAC = strMAC
            self.strSelectedIP = strIP
        except KeyError:
            print "Error: no selected RedPitaya."
            return
        # connect to the selected RedPitaya
        self.dev.OpenTCPConnection(self.strSelectedIP)
        # send new monitor-tcp version
        self.dev.write_file_on_remote(strFilenameLocal=self.qedit_software.text(), strFilenameRemote='/opt/monitor-tcp-new')
        
        # set executable permissions
        self.dev.send_shell_command('chmod +x /opt/monitor-tcp-new')
        # copy over old file
        self.dev.send_shell_command('mv /opt/monitor-tcp-new /opt/monitor-tcp')
        
        # send "reboot monitor-tcp" command
        self.dev.send_reboot_command()
        self.dev.sock.shutdown(socket.SHUT_RDWR)
        self.dev.sock.close()
        
        time.sleep(1) # give some time for tcp server to come back up
        pass

    def cancelClicked(self):
        self.bOk = False
        self.close()
        
    def closeEvent(self, e):
#        print('close')
        return
