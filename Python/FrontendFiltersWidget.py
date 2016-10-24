
import os
import csv
from PyQt4 import QtCore, Qt, QtGui, uic, Qwt5

from ControlWidget import ControlWidget
from virtex7_registers import virtex7_registers as regs
from data_utilities import *



  
class FrontendFiltersWidget(ControlWidget):
    def __init__(self, parent, channel_number):
        super(FrontendFiltersWidget, self).__init__(parent)
        uic.loadUi("FrontendFiltersWidget.ui", self)
        self.channel_number = channel_number
        
        self.BASEADDR_FRONTEND_FILTS = regs.BASEADDR_FRONTEND_FILTS[self.channel_number]
        self.setWindowTitle("Frontend Filters, channel %i" % self.channel_number)

        self.COEF_NUM_TO_LOAD_NUM = range(279, -1, -1)
        self.COEF_COUNT = 280
        
        self.ydata = self.COEF_COUNT*[0]
        self.xdata = range(self.COEF_COUNT)
    
        self.curve = Qwt5.QwtPlotCurve("Matched Filter")
        self.curve.setPen(Qt.QColor(0,128,0))
        self.curve.attach(self.plotMatchedFilter)
        self.curve.setData(self.xdata, self.ydata)
        self.plotMatchedFilter.replot()
        self.plotMatchedFilter.setAxisScale(Qwt5.QwtPlot.xBottom, 0, 279)
        self.plotMatchedFilter.setAxisScale(Qwt5.QwtPlot.yLeft, -1.0, 1.0)
        self.plotMatchedFilter.setCanvasBackground(Qt.QColor(255,255,255))
        
        self.bBypassHPF = False
        self.bBypassMF = False
        
        self.checkBypassHPF.clicked.connect(self.checkBypassHPF_clicked)
        self.checkBypassMF.clicked.connect(self.checkBypassMF_clicked)
        self.buttonRead.clicked.connect(self.buttonRead_clicked)
        # self.buttonWrite.clicked.connect(self.buttonWrite_clicked)
        self.buttonLoad.clicked.connect(self.buttonLoad_clicked)
        self.buttonSave.clicked.connect(self.buttonSave_clicked)
        
        
    def checkBypassHPF_clicked(self):
        self.bBypassHPF = self.checkBypassHPF.isChecked()
        self.ibus_write(self.BASEADDR_FRONTEND_FILTS+regs.OFFSET_FRONTEND_HPF_BYPASS, [int(self.bBypassHPF)])
        
    def checkBypassMF_clicked(self):
        self.bBypassMF = self.checkBypassMF.isChecked()
        self.ibus_write(self.BASEADDR_FRONTEND_FILTS+regs.OFFSET_FRONTEND_MF_BYPASS, [int(self.bBypassMF)])
        
    def buttonRead_clicked(self):
        self.readStatus()
        self.readMatchedFilter()
        self.updateControls()
    
    # def buttonWrite_clicked(self):
    #     self.writeMatchedFilter()
    
    def buttonLoad_clicked(self):
        filename = QtGui.QFileDialog.getOpenFileName(None, caption='Open file', filter="*.csv")
        if os.path.exists(filename) == False:
            return
        with open(filename, 'r') as csvfile:
            reader = csv.reader(csvfile, dialect='excel')
            line_index = 0
            for row in reader:
                if line_index > 0:
                    try:
                        coef_index = int(row[0])
                        load_index = int(row[1])
                        value = int(row[2])
                        self.COEF_NUM_TO_LOAD_NUM[coef_index] = load_index
                        self.ydata[coef_index] = value
                    except ValueError:
                        return
                line_index = line_index + 1
                
        self.writeMatchedFilter()
        
        self.updatePlot()
    
    def buttonSave_clicked(self):
        pass
    
 
    def readStatus(self):
        ret = self.ibus_read(self.BASEADDR_FRONTEND_FILTS+regs.OFFSET_FRONTEND_HPF_BYPASS, 1)
        if ret is not None:
            self.bBypassHPF = ((ret[0]&0x01)==0x01)
        ret = self.ibus_read(self.BASEADDR_FRONTEND_FILTS+regs.OFFSET_FRONTEND_MF_BYPASS, 1)
        if ret is not None:
            self.bBypassMF = ((ret[0]&0x01)==0x01)
        
    def readMatchedFilter(self):
        for i in range(self.COEF_COUNT):
            a = self.COEF_NUM_TO_LOAD_NUM[i]
            addr_msb = (a>>8)&0xFF
            addr_lsb = a&0xFF
            self.ibus_write(self.BASEADDR_FRONTEND_FILTS+regs.OFFSET_FRONTEND_FILTS_COEF_ADDR, 
                            [addr_msb,addr_lsb])
            ret = self.ibus_read(self.BASEADDR_FRONTEND_FILTS+regs.OFFSET_FRONTEND_FILTS_COEF_DATA, 4)
            if ret is not None:
                self.ydata[i] = bytes2int(ret)
        
    def writeMatchedFilter(self):
        for i in range(self.COEF_COUNT):
            a = self.COEF_NUM_TO_LOAD_NUM[i]
            addr_msb = (a>>8)&0xFF
            addr_lsb = a&0xFF
            self.ibus_write(self.BASEADDR_FRONTEND_FILTS+regs.OFFSET_FRONTEND_FILTS_COEF_ADDR, 
                            [addr_msb,addr_lsb])
            self.ibus_write(self.BASEADDR_FRONTEND_FILTS+regs.OFFSET_FRONTEND_FILTS_COEF_DATA, 
                            int2bytes(self.ydata[i], 4))
        self.ibus_write(self.BASEADDR_FRONTEND_FILTS+regs.OFFSET_FRONTEND_FILTS_COEF_LOAD, [1])
        
    def updatePlot(self):
        self.curve.setData(self.xdata, self.ydata)
        self.plotMatchedFilter.setAxisScale(Qwt5.QwtPlot.yLeft, min(self.ydata), max(self.ydata))
        self.plotMatchedFilter.replot()   

    def updateControls(self):
        
        self.checkBypassHPF.setChecked(self.bBypassHPF)
        self.checkBypassMF.setChecked(self.bBypassMF)
        self.updatePlot()
        
    def update_content(self):    
        self.readStatus()
        self.readMatchedFilter()
        self.updateControls()
    