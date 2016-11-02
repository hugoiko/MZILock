
from PyQt4 import QtCore, Qt, QtGui, uic

from ControlWidget import ControlWidget
from DeviceAssociations import *
from UDPRedPitayaDiscovery import UDPRedPitayaDiscovery
import re
import time
import os
        
class TCPConnectionWidget(ControlWidget):

    BROADCAST_REPLY_WAIT_TIMEOUT = 0.1
    FPGA_PROGRAMMING_TIME = 1.0

    def __init__(self, parent, UDPDiscovery, dev):
        super(TCPConnectionWidget, self).__init__(parent)
        uic.loadUi("TCPConnectionWidget.ui", self)
        
        self.parent = parent

        self.IP_pattern  =  "([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})"

        self.UDPDiscovery = UDPDiscovery
        self.dev = dev

        self.strIP_list     = list()
        self.strMAC_list    = list()
        self.color_list     = list()
        self.name_list      = list()
        self.shorthand_list = list()

        self.strIPcurrent = "";

        self.buttonScan.clicked.connect(self.buttonScan_clicked)
        self.buttonConnect.clicked.connect(self.buttonConnect_clicked)
        self.buttonDisconnect.clicked.connect(self.buttonDisconnect_clicked)

        self.buttonUpdateFPGA.clicked.connect(self.buttonUpdateFPGA_clicked)
        self.buttonUpdateCPU.clicked.connect(self.buttonUpdateCPU_clicked)
        
    def buttonUpdateFPGA_clicked(self):
        filename = QtGui.QFileDialog.getOpenFileName(None, caption='Please select the FPGA bitfile', filter="*.bit")
        if os.path.exists(filename) == False:
            return
        if self.dev.bConnected:
            self.dev.write_file_on_remote(strFilenameLocal=filename, strFilenameRemote='/opt/red_pitaya_top.bit')
            self.dev.send_shell_command('cat /opt/red_pitaya_top.bit > /dev/xdevcfg')
            time.sleep(self.FPGA_PROGRAMMING_TIME)
            self.parent.update_widgets_content()

    def buttonUpdateCPU_clicked(self):
        filename = QtGui.QFileDialog.getOpenFileName(None, caption='Please select the CPU program', filter="*.*")
        if os.path.exists(filename) == False:
            return

        if self.dev.bConnected:
            # write new file
            self.dev.write_file_on_remote(strFilenameLocal=filename, strFilenameRemote='/opt/monitor-tcp-new')
            # set executable permissions
            self.dev.send_shell_command('chmod +x /opt/monitor-tcp-new')
            # copy over old file
            self.dev.send_shell_command('mv /opt/monitor-tcp-new /opt/monitor-tcp')
            
            # send "reboot monitor-tcp" command
            self.dev.send_reboot_command()

            self.dev.CloseTCPConnection()
            self.parent.change_mdi_color(self.parent.defaultColor)
            self.parent.setWindowTitle(self.parent.defaultTitle)
            self.parent.update_widgets_connection_status(self.dev.bConnected)
        
            

    def update_connection_status(self, bConnected):
        self.comboDevices.setEnabled(not bConnected)
        self.editBroadcastAddress.setEnabled(not bConnected)
        self.buttonScan.setEnabled(not bConnected)
        self.buttonConnect.setEnabled(not bConnected)
        self.buttonDisconnect.setEnabled(bConnected)
        self.buttonUpdateFPGA.setEnabled(bConnected)
        self.buttonUpdateCPU.setEnabled(bConnected)

    def buttonConnect_clicked(self):
        index = self.comboDevices.currentIndex()
        if index >= 0:
            self.strIPcurrent = self.strIP_list[index];
            value = self.dev.OpenTCPConnection(self.strIPcurrent)
            if value is not None:
                QtGui.QMessageBox.critical(self, "Connection Error", str(value))
            if self.dev.bConnected:
                self.parent.change_mdi_color(self.color_list[index])
                self.parent.setWindowTitle(self.name_list[index])
                self.parent.update_widgets_connection_status(self.dev.bConnected)
                self.parent.update_widgets_content()


    def buttonDisconnect_clicked(self):
        if self.dev.bConnected:
            self.dev.CloseTCPConnection()
            self.parent.change_mdi_color(self.parent.defaultColor)
            self.parent.setWindowTitle(self.parent.defaultTitle)
            self.parent.update_widgets_connection_status(self.dev.bConnected)

    def buttonScan_clicked(self):

        m = re.match(self.IP_pattern, self.editBroadcastAddress.text())
        if m is not None:
            dstIP = ""
            for s in m.groups():
                dstIP += "%d." % (int(s))
            dstIP = dstIP[:-1]
            #print(dstIP)
            self.UDPDiscovery.broadcast_address = dstIP
            self.UDPDiscovery.send_broadcast()

            self.strIP_list     = list()
            self.strMAC_list    = list()
            self.color_list     = list()
            self.name_list      = list()
            self.shorthand_list = list()

            time.sleep(self.BROADCAST_REPLY_WAIT_TIMEOUT)

            (strIP, strMAC) = self.UDPDiscovery.check_answers()
            while (strIP is not None):
                self.strIP_list.append(strIP)
                self.strMAC_list.append(strMAC)
                (strIP, strMAC) = self.UDPDiscovery.check_answers()

            for strMAC in self.strMAC_list:
                if strMAC in devices_data:
                    self.color_list.append(devices_data[strMAC]['color'])
                    self.name_list.append(devices_data[strMAC]['name'])
                    self.shorthand_list.append(devices_data[strMAC]['shorthand'])
                else:
                    self.color_list.append('#CCCCCC')
                    self.name_list.append('Unknown RedPitaya')
                    self.shorthand_list.append('Unknown')


            self.comboDevices.clear()
            for i in range(len(self.strIP_list)):
                strDisplay = '%s: %s %s' % (self.name_list[i], self.strMAC_list[i], self.strIP_list[i])
                self.comboDevices.addItem(strDisplay)


        else:
            QtGui.QMessageBox.critical(self, "Error", "Invalid Broadcast Address")

        pass
