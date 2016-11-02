import sys

from PyQt4 import QtCore, Qt, QtGui, uic, Qwt5
import pyqtgraph
import numpy

from ControlWidget import ControlWidget

import time
  
class LoopFilterWidget(ControlWidget):
    def __init__(self, parent, dev):
        super(LoopFilterWidget, self).__init__(parent)
        uic.loadUi("LoopFilterWidget.ui", self)
        self.dev = dev
        self.parent = parent

        self.REG_ADDR_CLR           = 0x00080
        self.REG_ADDR_LOCK          = 0x00084
        self.REG_ADDR_COEF_D_FILT   = 0x00088
        self.REG_ADDR_CMD_IN_D      = 0x0008C
        self.REG_ADDR_CMD_IN_P      = 0x00090
        self.REG_ADDR_CMD_IN_I      = 0x00094
        self.REG_ADDR_CMD_IN_II     = 0x00098
        self.REG_ADDR_DITHER_EN     = 0x0009C
        self.REG_ADDR_DITHER_AMPLI  = 0x000A0
        self.REG_ADDR_DITHER_PERIOD = 0x000A4

        self.REG_ADDR_BRANCH_EN_D   = 0x000A8
        self.REG_ADDR_BRANCH_EN_P   = 0x000AC
        self.REG_ADDR_BRANCH_EN_I   = 0x000B0
        self.REG_ADDR_BRANCH_EN_II  = 0x000B4
        
        # timerPeriod_secs = 0.03

        # self.timer = QtCore.QTimer(self)
        # self.timer.timeout.connect(self.update)
        # self.timer.start(round(1000*timerPeriod_secs))

        self.checkLockEnabled.clicked.connect(self.checkLockEnabled_clicked)
        self.buttonClearIntegrators.clicked.connect(self.buttonClearIntegrators_clicked)

        self.checkBranchEnabledD.clicked.connect(self.checkBranchEnabledP_clicked)
        self.checkBranchEnabledP.clicked.connect(self.checkBranchEnabledP_clicked)
        self.checkBranchEnabledI.clicked.connect(self.checkBranchEnabledI_clicked)
        self.checkBranchEnabledII.clicked.connect(self.checkBranchEnabledII_clicked)

        self.checkDitherEnabled.clicked.connect(self.checkDitherEnabled_clicked)

        self.editDitherPeriod.editingFinished.connect(self.editDitherPeriod_editingFinished)
        self.editDitherAmpli.editingFinished.connect(self.editDitherAmpli_editingFinished)

        self.editGainFD.editingFinished.connect(self.editGainFD_editingFinished)
        self.editGainD.editingFinished.connect(self.editGainD_editingFinished)
        self.editGainP.editingFinished.connect(self.editGainP_editingFinished)
        self.editGainI.editingFinished.connect(self.editGainI_editingFinished)
        self.editGainII.editingFinished.connect(self.editGainII_editingFinished)
                
    def update(self):
        pass
            
    def float_to_hdr_gain_code(self, gain, max_shifts=None):
        MAX_SHIFTERS = 6
        if max_shifts is None:
            max_shifts = MAX_SHIFTERS
        if max_shifts > MAX_SHIFTERS:
            ValueError("Unsupported number of shifters")
            
        if gain == 0.0:
            return (0, 0.0)

        log256_gain = numpy.log(numpy.abs(gain))/numpy.log(256.0)
        log256_sign = numpy.sign(log256_gain)
        n_shifts = numpy.floor(numpy.abs(log256_gain))
        gain_mant = numpy.round((2.0**16.0)* gain * 256.0**(-log256_sign*n_shifts))

        if n_shifts > max_shifts:
            n_shifts = max_shifts

        actual_gain = (2.0**-16.0) * gain_mant * 256.0**(log256_sign*n_shifts)

        code = 0x80000000
        if int(log256_sign) == -1:
            code = 0x00000000

        shift_codes = [0x00000000, 0x02000000, 0x06000000, 0x0E000000, 0x1E000000, 0x3E000000, 0x7E000000]
        code |= shift_codes[int(n_shifts)]

        mant_mask = 0x01FFFFFF
        code |= (int(gain_mant) & mant_mask)

        return (code, actual_gain)

    def hdr_gain_code_to_float(self, code):
        log256_sign = -1.0
        if (int(code) & 0x80000000):
            log256_sign = 1.0

        n_shifts = 0.0

        if (int(code) & 0x40000000):
            n_shifts += 1.0
        if (int(code) & 0x20000000):
            n_shifts += 1.0
        if (int(code) & 0x10000000):
            n_shifts += 1.0
        if (int(code) & 0x08000000):
            n_shifts += 1.0
        if (int(code) & 0x04000000):
            n_shifts += 1.0
        if (int(code) & 0x02000000):
            n_shifts += 1.0

        mant_mask = 0x01FFFFFF
        gain_mant = int(code) & mant_mask
        if (gain_mant & 0x01000000):
            gain_mant = gain_mant - 0x02000000

        actual_gain = (2.0**-16.0) * gain_mant * 256.0**(log256_sign*n_shifts)

        return actual_gain

    def update_content(self):

        self.checkBranchEnabledD.setChecked(bool(self.dev.read_Zynq_register_uint32(self.REG_ADDR_BRANCH_EN_D)))
        self.checkBranchEnabledP.setChecked(bool(self.dev.read_Zynq_register_uint32(self.REG_ADDR_BRANCH_EN_P)))
        self.checkBranchEnabledI.setChecked(bool(self.dev.read_Zynq_register_uint32(self.REG_ADDR_BRANCH_EN_I)))
        self.checkBranchEnabledII.setChecked(bool(self.dev.read_Zynq_register_uint32(self.REG_ADDR_BRANCH_EN_II)))

        self.checkLockEnabled.setChecked(bool(self.dev.read_Zynq_register_uint32(self.REG_ADDR_LOCK)))
        self.buttonClearIntegrators.setChecked(bool(self.dev.read_Zynq_register_uint32(self.REG_ADDR_CLR)))

        self.checkDitherEnabled.setChecked(bool(self.dev.read_Zynq_register_uint32(self.REG_ADDR_DITHER_EN)))

        self.editDitherPeriod.setText(str(self.dev.read_Zynq_register_uint32(self.REG_ADDR_DITHER_PERIOD)))
        self.editDitherAmpli.setText(str(self.dev.read_Zynq_register_uint32(self.REG_ADDR_DITHER_AMPLI)))

        self.editGainFD.setText(str(self.dev.read_Zynq_register_int32(self.REG_ADDR_COEF_D_FILT)))
        self.editGainD.setText( "%g"%(self.hdr_gain_code_to_float(self.dev.read_Zynq_register_uint32(self.REG_ADDR_CMD_IN_D))))
        self.editGainP.setText( "%g"%(self.hdr_gain_code_to_float(self.dev.read_Zynq_register_uint32(self.REG_ADDR_CMD_IN_P))))
        self.editGainI.setText( "%g"%(self.hdr_gain_code_to_float(self.dev.read_Zynq_register_uint32(self.REG_ADDR_CMD_IN_I))))
        self.editGainII.setText("%g"%(self.hdr_gain_code_to_float(self.dev.read_Zynq_register_uint32(self.REG_ADDR_CMD_IN_II))))
        
    def checkBranchEnabledD_clicked(self):
        self.dev.write_Zynq_register_uint32(self.REG_ADDR_BRANCH_EN_D , int(self.checkBranchEnabledD.isChecked()))
    def checkBranchEnabledP_clicked(self):
        self.dev.write_Zynq_register_uint32(self.REG_ADDR_BRANCH_EN_P , int(self.checkBranchEnabledP.isChecked()))
    def checkBranchEnabledI_clicked(self):
        self.dev.write_Zynq_register_uint32(self.REG_ADDR_BRANCH_EN_I , int(self.checkBranchEnabledI.isChecked()))
    def checkBranchEnabledII_clicked(self):
        self.dev.write_Zynq_register_uint32(self.REG_ADDR_BRANCH_EN_II , int(self.checkBranchEnabledII.isChecked()))

    def checkDitherEnabled_clicked(self):
        self.dev.write_Zynq_register_uint32(self.REG_ADDR_DITHER_EN, int(self.checkDitherEnabled.isChecked()))

    def checkLockEnabled_clicked(self):
        self.dev.write_Zynq_register_uint32(self.REG_ADDR_LOCK, int(self.checkLockEnabled.isChecked()))

    def buttonClearIntegrators_clicked(self):
        self.dev.write_Zynq_register_uint32(self.REG_ADDR_CLR, int(self.buttonClearIntegrators.isChecked()))


    def editDitherPeriod_editingFinished(self):
        try:
            val = int(self.editDitherPeriod.text())
            self.dev.write_Zynq_register_uint32(self.REG_ADDR_DITHER_PERIOD, val)
        except ValueError:
            pass
    def editDitherAmpli_editingFinished(self):
        try:
            val = int(self.editDitherAmpli.text())
            self.dev.write_Zynq_register_uint32(self.REG_ADDR_DITHER_AMPLI, val)
        except ValueError:
            pass


    def editGainFD_editingFinished(self):
        try:
            val = int(self.editGainFD.text())
            self.dev.write_Zynq_register_uint32(self.REG_ADDR_COEF_D_FILT, val)
        except ValueError:
            pass
    def editGainD_editingFinished(self):
        try:
            val = float(self.editGainD.text())
            (code, act) = self.float_to_hdr_gain_code(val, 0)
            self.editGainD.setText("%g"%(act))
            self.dev.write_Zynq_register_uint32(self.REG_ADDR_CMD_IN_D, code)
        except ValueError:
            pass
    def editGainP_editingFinished(self):
        try:
            val = float(self.editGainP.text())
            (code, act) = self.float_to_hdr_gain_code(val, 0)
            self.editGainP.setText("%g"%(act))
            self.dev.write_Zynq_register_uint32(self.REG_ADDR_CMD_IN_P, code)
        except ValueError:
            pass
    def editGainI_editingFinished(self):
        try:
            val = float(self.editGainI.text())
            (code, act) = self.float_to_hdr_gain_code(val, 3)
            self.editGainI.setText("%g"%(act))
            self.dev.write_Zynq_register_uint32(self.REG_ADDR_CMD_IN_I, code)
        except ValueError:
            pass
    def editGainII_editingFinished(self):
        try:
            val = float(self.editGainII.text())
            (code, act) = self.float_to_hdr_gain_code(val, 6)
            self.editGainII.setText("%g"%(act))
            self.dev.write_Zynq_register_uint32(self.REG_ADDR_CMD_IN_II, code)
        except ValueError:
            pass


if __name__ == "__main__":

    app = QtGui.QApplication(sys.argv)  
    test = LoopFilterWidget(None, None)
    
    gain = 0
    (code, actual_gain) = test.float_to_hdr_gain_code(gain, 6)
    recomp_gain = test.hdr_gain_code_to_float(code)
    print("%g -> 0x%08X -> %g, %g\n" % (gain, code, actual_gain, recomp_gain))
    
    app.exec_()
    