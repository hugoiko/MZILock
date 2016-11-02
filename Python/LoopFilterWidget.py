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

        self.FS = 125.0e6

        self.curve1 = Qwt5.QwtPlotCurve("Asymptotes")
        self.curve1.setPen(Qt.QColor(0, 64, 0))
        self.curve1.attach(self.graph)
        self.curve1.setData([], [])

        self.curve2 = Qwt5.QwtPlotCurve("Actual magnitude")
        self.curve2.setPen(Qt.QColor(0, 255, 0))
        self.curve2.attach(self.graph)
        self.curve2.setData([], [])

        self.curve3 = Qwt5.QwtPlotCurve("Actual phase")
        self.curve3.setPen(Qt.QColor(255, 0, 255))
        self.curve3.attach(self.graph)
        self.curve3.setYAxis(Qwt5.QwtPlot.yRight)
        self.curve3.setData([], [])

        self.grid = Qwt5.QwtPlotGrid()
        self.grid.attach(self.graph)

        self.graph.replot()
        self.graph.setAxisTitle(Qwt5.QwtPlot.xBottom, "Frequency [Hz]")
        self.graph.setAxisScaleEngine(Qwt5.QwtPlot.xBottom, Qwt5.QwtLog10ScaleEngine())
        #self.graph.setAxisScale(Qwt5.QwtPlot.xBottom, 1e3, 1e6)
        self.graph.enableAxis(Qwt5.QwtPlot.yRight)
        self.graph.setAxisTitle(Qwt5.QwtPlot.yRight, "Phase [degrees]")
        #self.graph.setAxisScale(Qwt5.QwtPlot.yRight, -1080, 1e2)

        self.graph.setAxisTitle(Qwt5.QwtPlot.yLeft, "Magnitude [V/rad]")
        self.graph.setAxisScaleEngine(Qwt5.QwtPlot.yLeft, Qwt5.QwtLog10ScaleEngine())
        #self.graph.setAxisScale(Qwt5.QwtPlot.yLeft, 1e-6, 1e2)
        self.graph.setCanvasBackground(Qt.QColor(32,32,32))
        
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

        self.checkFlipPlotSign.clicked.connect(self.update_transfer_function)
                
    def update(self):
        pass

    def update_transfer_function(self):


        freq_axis = numpy.logspace(-2,8, num=1000, endpoint=False);
        wn = 2*numpy.pi*freq_axis/self.FS

        zrec = numpy.exp(-1j*wn)

        bFlipSign = self.checkFlipPlotSign.isChecked()

        try:
            cn  = float(self.editGainFD.text()) / float(2**24)
            Kd  = 0.0
            Kp  = 0.0
            Ki  = 0.0
            Kii = 0.0
            if self.checkBranchEnabledD.isChecked():
                Kd  = float(self.editGainD.text())
            if self.checkBranchEnabledP.isChecked():
                Kp  = float(self.editGainP.text())
            if self.checkBranchEnabledI.isChecked():
                Ki  = float(self.editGainI.text())
            if self.checkBranchEnabledII.isChecked():
                Kii = float(self.editGainII.text())
        except ValueError:
            print("Bad value")
            pass

        asympt_DF = numpy.absolute(Kd*cn)*numpy.ones(wn.shape)
        asympt_D = numpy.absolute(Kd)*numpy.absolute(wn)
        asympt_P = numpy.absolute(Kp)*numpy.ones(wn.shape)
        asympt_I = numpy.absolute(Ki)/numpy.absolute(wn)
        asympt_II = numpy.absolute(Kii)/(numpy.absolute(wn)**2)

        asympt = numpy.minimum(asympt_DF, asympt_D)
        asympt = numpy.maximum(asympt, asympt_P)
        asympt = numpy.maximum(asympt, asympt_I)
        asympt = numpy.maximum(asympt, asympt_II)

        actual_d = Kd*(zrec**4)*(1-zrec)*cn/(1+(-1+cn)*zrec)
        actual_p = Kp*(zrec**3)
        actual_i = Ki*(zrec**8)*zrec/(1-zrec)
        actual_ii= Kii*(zrec**12)*(zrec/(1-zrec))**2

        pid_scaling = (1048576.0/(2.0*numpy.pi*65536/2.0))

        asympt = asympt * pid_scaling

        actual_function = (actual_d + actual_p + actual_i + actual_ii)*pid_scaling
        if bFlipSign:
            actual_function = -actual_function

        magn = numpy.absolute(actual_function)
        rangle = (360.0/(2.0*numpy.pi))*numpy.angle(actual_function)

        log_magn = 10.0*numpy.log10(magn)
        log_asympt = 10.0*numpy.log10(asympt)

        self.curve1.setData(freq_axis, asympt)
        self.curve2.setData(freq_axis, magn)
        self.curve3.setData(freq_axis, rangle)
        #self.graph.setAxisScale(Qwt5.QwtPlot.yLeft, numpy.amin(log_magn), numpy.amax(log_magn))
        self.graph.replot()

        scaling_to_hertz = float(self.FS)/(2.0*numpy.pi)
        strInfo  = ""
        if Kd != 0.0:
            strInfo += "D-P crossing  : %g Hz\n" % float(scaling_to_hertz*numpy.absolute(Kp/Kd))
            strInfo += "D cutoff      : %g Hz\n" % float(scaling_to_hertz*numpy.absolute(cn))
        if Kp != 0.0:
            strInfo += "P-I crossing  : %g Hz\n" % float(scaling_to_hertz*numpy.absolute(Ki/Kp))
            strInfo += "P-II crossing : %g Hz\n" % float(scaling_to_hertz*numpy.sqrt(numpy.absolute(Kii/Kp)))
        if Ki != 0.0:
            strInfo += "II-I crossing : %g Hz\n" % float(scaling_to_hertz*numpy.absolute(Kii/Ki))


        self.textInfo.setPlainText(strInfo)


    
    def float_to_hdr_gain_code(self, gain, max_shifts=None):
        MAX_SHIFTERS = 6
        if max_shifts is None:
            max_shifts = MAX_SHIFTERS
        if max_shifts > MAX_SHIFTERS:
            ValueError("Unsupported number of shifters")
            
        if gain == 0.0:
            return (0, 0.0)
            
        MINIMUM_GAIN = (2.0**-16.0)
        MAXIMUM_GAIN = (2.0**8.0)

        curr_mant = gain;
        
        n_right_shifts = 0
        while (abs(curr_mant) < MINIMUM_GAIN or n_right_shifts < max_shifts) and (abs(curr_mant)*256.0 <= MAXIMUM_GAIN):
            n_right_shifts += 1
            curr_mant *= 256.0
            
        n_left_shifts = 0
        while (abs(curr_mant) > MAXIMUM_GAIN):
            n_left_shifts += 1
            curr_mant /= 256.0
            
        gain_mant = round((2.0**16.0)*curr_mant)
        
        actual_gain = (2.0**-16.0) * gain_mant * 256.0**(n_left_shifts-n_right_shifts)
            
        if n_right_shifts and n_left_shifts:
            raise Exception("Both right shifts and left shifts")
            
        code = 0x80000000
        if n_right_shifts != 0 and n_left_shifts == 0:
            code = 0x00000000

        n_shifts = n_right_shifts+n_left_shifts  
            
        shift_codes = [0x00000000, 0x02000000, 0x06000000, 0x0E000000, 0x1E000000, 0x3E000000, 0x7E000000]
        code |= shift_codes[int(n_shifts)]

        mant_mask = 0x01FFFFFF
        code |= (int(gain_mant) & mant_mask)
        
        return (code, actual_gain)

        
            
#    def float_to_hdr_gain_code(self, gain, max_shifts=None):
#        MAX_SHIFTERS = 6
#        if max_shifts is None:
#            max_shifts = MAX_SHIFTERS
#        if max_shifts > MAX_SHIFTERS:
#            ValueError("Unsupported number of shifters")
#            
#        if gain == 0.0:
#            return (0, 0.0)
#
#        log256_gain = numpy.log(numpy.abs(gain))/numpy.log(256.0)
#        log256_sign = numpy.sign(log256_gain)
#        n_shifts = numpy.floor(numpy.abs(log256_gain))
#        gain_mant = numpy.round((2.0**16.0)* gain * 256.0**(-log256_sign*n_shifts))
#
#        if n_shifts > max_shifts:
#            n_shifts = max_shifts
#
#        actual_gain = (2.0**-16.0) * gain_mant * 256.0**(log256_sign*n_shifts)
#
#        code = 0x80000000
#        if int(log256_sign) == -1:
#            code = 0x00000000
#
#        shift_codes = [0x00000000, 0x02000000, 0x06000000, 0x0E000000, 0x1E000000, 0x3E000000, 0x7E000000]
#        code |= shift_codes[int(n_shifts)]
#
#        mant_mask = 0x01FFFFFF
#        code |= (int(gain_mant) & mant_mask)
#
#        return (code, actual_gain)

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
        self.editGainD.setText( "%.16f"%(self.hdr_gain_code_to_float(self.dev.read_Zynq_register_uint32(self.REG_ADDR_CMD_IN_D))))
        self.editGainP.setText( "%.16f"%(self.hdr_gain_code_to_float(self.dev.read_Zynq_register_uint32(self.REG_ADDR_CMD_IN_P))))
        self.editGainI.setText( "%.16f"%(self.hdr_gain_code_to_float(self.dev.read_Zynq_register_uint32(self.REG_ADDR_CMD_IN_I))))
        self.editGainII.setText("%.16f"%(self.hdr_gain_code_to_float(self.dev.read_Zynq_register_uint32(self.REG_ADDR_CMD_IN_II))))
        
        self.update_transfer_function()

    def checkBranchEnabledD_clicked(self):
        self.dev.write_Zynq_register_uint32(self.REG_ADDR_BRANCH_EN_D , int(self.checkBranchEnabledD.isChecked()))
        self.update_transfer_function()
    def checkBranchEnabledP_clicked(self):
        self.dev.write_Zynq_register_uint32(self.REG_ADDR_BRANCH_EN_P , int(self.checkBranchEnabledP.isChecked()))
        self.update_transfer_function()
    def checkBranchEnabledI_clicked(self):
        self.dev.write_Zynq_register_uint32(self.REG_ADDR_BRANCH_EN_I , int(self.checkBranchEnabledI.isChecked()))
        self.update_transfer_function()
    def checkBranchEnabledII_clicked(self):
        self.dev.write_Zynq_register_uint32(self.REG_ADDR_BRANCH_EN_II , int(self.checkBranchEnabledII.isChecked()))
        self.update_transfer_function()

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

    def fd_coef_to_cutoff(self, coef, fs):
        a = (float(2**24) - float(coef))/float(2**24)
        return (float(fs)*a)/(float(2.0*numpy.pi))

    def cutoff_to_fd_coef(self, cutoff, fs):
        coef = (float(2.0*numpy.pi)*float(2**24))*float(cutoff)/(float(fs))
        if coef > 2**24-1:
            coef = 2**24-1
        if coef < 0:
            coef = 0

    def editGainFD_editingFinished(self):
        try:
            val = int(self.editGainFD.text())
            self.dev.write_Zynq_register_uint32(self.REG_ADDR_COEF_D_FILT, val)
            self.update_transfer_function()
        except ValueError:
            pass

    def editGainD_editingFinished(self):
        try:
            val = float(self.editGainD.text())
            (code, act) = self.float_to_hdr_gain_code(val, 0)
            self.editGainD.setText("%.16f"%(act))
            self.dev.write_Zynq_register_uint32(self.REG_ADDR_CMD_IN_D, code)
            self.update_transfer_function()
        except ValueError:
            pass

    def editGainP_editingFinished(self):
        try:
            val = float(self.editGainP.text())
            (code, act) = self.float_to_hdr_gain_code(val, 0)
            self.editGainP.setText("%.16f"%(act))
            self.dev.write_Zynq_register_uint32(self.REG_ADDR_CMD_IN_P, code)
            self.update_transfer_function()
        except ValueError:
            pass

    def editGainI_editingFinished(self):
        try:
            val = float(self.editGainI.text())
            (code, act) = self.float_to_hdr_gain_code(val, 3)
            self.editGainI.setText("%.16f"%(act))
            self.dev.write_Zynq_register_uint32(self.REG_ADDR_CMD_IN_I, code)
            self.update_transfer_function()
        except ValueError:
            pass

    def editGainII_editingFinished(self):
        try:
            val = float(self.editGainII.text())
            (code, act) = self.float_to_hdr_gain_code(val, 6)
            self.editGainII.setText("%.16f"%(act))
            self.dev.write_Zynq_register_uint32(self.REG_ADDR_CMD_IN_II, code)
            self.update_transfer_function()
        except ValueError:
            pass



if __name__ == "__main__":

    app = QtGui.QApplication(sys.argv)  
    test = LoopFilterWidget(None, None)
    
    gain = -10
    #test.float_to_hdr_gain_code_v2(gain, 6)
    (code, actual_gain) = test.float_to_hdr_gain_code(gain, 3)
    recomp_gain = test.hdr_gain_code_to_float(code)
    print("%g -> 0x%08X -> %g, %g\n" % (gain, code, actual_gain, recomp_gain))
    
    app.exec_()
    