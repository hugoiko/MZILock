import sys

from PyQt4 import QtCore, Qt, QtGui, uic, Qwt5
import pyqtgraph
import numpy

from ControlWidget import ControlWidget

import time
  
class IQCalibrationWidget(ControlWidget):
    def __init__(self, parent, dev):
        super(IQCalibrationWidget, self).__init__(parent)
        uic.loadUi("IQCalibrationWidget.ui", self)
        self.dev = dev
        self.parent = parent
        self.calc = self.parent.calc

        self.buttonEstimateValues.clicked.connect(self.buttonEstimateValues_clicked)
        self.buttonCopy.clicked.connect(self.buttonCopy_clicked)

        self.editCurrentB11.editingFinished.connect(self.editCurrentB11_editingFinished)
        self.editCurrentB21.editingFinished.connect(self.editCurrentB21_editingFinished)
        self.editCurrentA11.editingFinished.connect(self.editCurrentA11_editingFinished)
        self.editCurrentA21.editingFinished.connect(self.editCurrentA21_editingFinished)
        self.editCurrentA12.editingFinished.connect(self.editCurrentA12_editingFinished)
        self.editCurrentA22.editingFinished.connect(self.editCurrentA22_editingFinished)
        
        self.REG_ADDR_B11 = 0x00040
        self.REG_ADDR_B21 = 0x00044
        self.REG_ADDR_A11 = 0x00048
        self.REG_ADDR_A21 = 0x0004C
        self.REG_ADDR_A12 = 0x00050
        self.REG_ADDR_A22 = 0x00054

        timerPeriod_secs = 0.05
        self.timer = QtCore.QTimer(self)
        self.timer.timeout.connect(self.update)
        self.timer.start(round(1000*timerPeriod_secs))


    def editCurrentB11_editingFinished(self):
        try:
            val = int(self.editCurrentB11.text())
            self.dev.write_Zynq_register_int32(self.REG_ADDR_B11, val)
        except ValueError:
            pass

    def editCurrentB21_editingFinished(self):
        try:
            val = int(self.editCurrentB21.text())
            self.dev.write_Zynq_register_int32(self.REG_ADDR_B21, val)
        except ValueError:
            pass

    def editCurrentA11_editingFinished(self):
        try:
            val = int(self.editCurrentA11.text())
            self.dev.write_Zynq_register_int32(self.REG_ADDR_A11, val)
        except ValueError:
            pass

    def editCurrentA21_editingFinished(self):
        try:
            val = int(self.editCurrentA21.text())
            self.dev.write_Zynq_register_int32(self.REG_ADDR_A21, val)
        except ValueError:
            pass

    def editCurrentA12_editingFinished(self):
        try:
            val = int(self.editCurrentA12.text())
            self.dev.write_Zynq_register_int32(self.REG_ADDR_A12, val)
        except ValueError:
            pass

    def editCurrentA22_editingFinished(self):
        try:
            val = int(self.editCurrentA22.text())
            self.dev.write_Zynq_register_int32(self.REG_ADDR_A22, val)
        except ValueError:
            pass


    def buttonEstimateValues_clicked(self):
        self.calc.start_IQ_cal(100)

    def buttonCopy_clicked(self):
        self.editCurrentB11.setText(self.editEstimatedB11.text())
        self.editCurrentB21.setText(self.editEstimatedB21.text())
        self.editCurrentA11.setText(self.editEstimatedA11.text())
        self.editCurrentA21.setText(self.editEstimatedA21.text())
        self.editCurrentA12.setText(self.editEstimatedA12.text())
        self.editCurrentA22.setText(self.editEstimatedA22.text())
        self.editCurrentB11_editingFinished()
        self.editCurrentB21_editingFinished()
        self.editCurrentA11_editingFinished()
        self.editCurrentA21_editingFinished()
        self.editCurrentA12_editingFinished()
        self.editCurrentA22_editingFinished()
                
    def update(self):
        
        percentComplete = 0.0
        if self.calc.IQ_cal_iterations > 0:
            percentComplete = 100.0 * float(self.calc.IQ_cal_counter) / float(self.calc.IQ_cal_iterations)

        self.progressBar.setValue(percentComplete)

        self.editEstimatedB11.setText(str(self.calc.IQ_cal_Bvect1))
        self.editEstimatedB21.setText(str(self.calc.IQ_cal_Bvect2))
        self.editEstimatedA11.setText(str(self.calc.IQ_cal_Amat11))
        self.editEstimatedA21.setText(str(self.calc.IQ_cal_Amat21))
        self.editEstimatedA12.setText(str(self.calc.IQ_cal_Amat12))
        self.editEstimatedA22.setText(str(self.calc.IQ_cal_Amat22))
            

    def update_content(self):
        self.editCurrentB11.setText(str(self.dev.read_Zynq_register_int32(self.REG_ADDR_B11)))
        self.editCurrentB21.setText(str(self.dev.read_Zynq_register_int32(self.REG_ADDR_B21)))
        self.editCurrentA11.setText(str(self.dev.read_Zynq_register_int32(self.REG_ADDR_A11)))
        self.editCurrentA21.setText(str(self.dev.read_Zynq_register_int32(self.REG_ADDR_A21)))
        self.editCurrentA12.setText(str(self.dev.read_Zynq_register_int32(self.REG_ADDR_A12)))
        self.editCurrentA22.setText(str(self.dev.read_Zynq_register_int32(self.REG_ADDR_A22)))


        
