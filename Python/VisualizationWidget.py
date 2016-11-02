import sys

from PyQt4 import QtCore, Qt, QtGui, uic, Qwt5
import pyqtgraph
import numpy
from RedPitayaDevice import RedPitayaDevice

from ControlWidget import ControlWidget

import time
  
class VisualizationWidget(ControlWidget):
    def __init__(self, parent, dev):
        super(VisualizationWidget, self).__init__(parent)
        uic.loadUi("VisualizationWidget.ui", self)
        self.dev = dev
        self.parent = parent
        self.calc = self.parent.calc


        # #self.curve1 = pyqtgraph.PlotDataItem()
        # #self.curve2 = pyqtgraph.PlotDataItem()
        # self.curve1 = pyqtgraph.ScatterPlotItem()
        # self.curve2 = pyqtgraph.ScatterPlotItem()
        # #self.curve1.setSize(1)
        # #self.curve1.setPen(None)
        # self.curve1.setPen(None)
        # self.curve2.setPen(None)
        # self.curve1.setBrush(color='#00FFFF')
        # self.curve2.setBrush(color='#FF00FF')
        # #self.curve1.setBrush(None)
        # #self.curve1.setSymbol(None)
        # self.plot1 = self.graph.addPlot(row=0, col=0, rowspan=1, colspan=1)
        # self.plot1.addItem(self.curve1)
        # self.plot1.addItem(self.curve2)
        # self.plot1.setLabel('left','Q [V]')
        # self.plot1.setLabel('bottom','I [V]')
        # self.plot1.setXRange(min=-32768,max=32767)
        # self.plot1.setYRange(min=-32768,max=32767)
        # self.plot1.setAspectLocked(lock=True, ratio=1)
        # self.curve1.setData(x=[],y=[])
        # self.curve2.setData(x=[],y=[])

        # self.plot2 = self.graph.addPlot(row=0, col=1, rowspan=1, colspan=1)
        # self.plot3 = self.graph.addPlot(row=1, col=0, rowspan=1, colspan=2)

        # self.curve4 = pyqtgraph.PlotDataItem()
        # self.plot3.addItem(self.curve4)
        # self.plot3.setYRange(min=-2**31,max=2**31-1)

        # # self.plot3.setLogMode(x=True)


        self.curve1 = Qwt5.QwtPlotCurve("Input")
        self.curve1.setPen(Qt.QColor(0, 102, 0))
        self.curve1.attach(self.graphA)
        self.curve1.setData([], [])

        self.curve2 = Qwt5.QwtPlotCurve("Output")
        self.curve2.setPen(Qt.QColor(0, 255, 0))
        self.curve2.attach(self.graphA)
        self.curve2.setData([], [])

        self.graphA.replot()
        self.graphA.setAxisTitle(Qwt5.QwtPlot.xBottom, "I [V]")
        self.graphA.setAxisScale(Qwt5.QwtPlot.xBottom, -32768, 32767)
        self.graphA.setAxisTitle(Qwt5.QwtPlot.yLeft, "Q [V]")
        self.graphA.setAxisScale(Qwt5.QwtPlot.yLeft, -32768, 32767)
        self.graphA.setCanvasBackground(Qt.QColor(0,0,0))

        self.curve3 = Qwt5.QwtPlotCurve("Angle")
        self.curve3.setPen(Qt.QColor(0, 255, 0))
        self.curve3.attach(self.graphB)
        self.curve3.setData([], [])

        self.graphB.replot()
        self.graphB.setAxisTitle(Qwt5.QwtPlot.xBottom, "Time [s]")
        self.graphB.setAxisScale(Qwt5.QwtPlot.xBottom, 0, 1023)
        self.graphB.setAxisTitle(Qwt5.QwtPlot.yLeft, "Phase [rad]")
        self.graphB.setAxisScale(Qwt5.QwtPlot.yLeft, -numpy.pi, numpy.pi)
        self.graphB.setCanvasBackground(Qt.QColor(0,0,0))

        self.curve4 = Qwt5.QwtPlotCurve("Loop Filter Output")
        self.curve4.setPen(Qt.QColor(0, 255, 0))
        self.curve4.attach(self.graphC)
        self.curve4.setData([], [])

        self.graphC.replot()
        self.graphC.setAxisTitle(Qwt5.QwtPlot.xBottom, "Time [s]")
        self.graphC.setAxisScale(Qwt5.QwtPlot.xBottom, 0, 1023)
        self.graphC.setAxisTitle(Qwt5.QwtPlot.yLeft, "Output [V]")
        self.graphC.setAxisScale(Qwt5.QwtPlot.yLeft, -32768, 32767)
        self.graphC.setCanvasBackground(Qt.QColor(0,0,0))

        self.curve5 = Qwt5.QwtPlotCurve("Spectrum")
        self.curve5.setPen(Qt.QColor(255, 255, 0))
        self.curve5.attach(self.graphD)
        self.curve5.setData([], [])

        self.graphD.replot()

        self.graphD.setAxisTitle(Qwt5.QwtPlot.xBottom, "Frequency [Hz]")
        self.graphD.setAxisScaleEngine(Qwt5.QwtPlot.xBottom, Qwt5.QwtLog10ScaleEngine())
        self.graphD.setAxisScale(Qwt5.QwtPlot.xBottom, 1e3, 1e6)

        self.graphD.setAxisTitle(Qwt5.QwtPlot.yLeft, "Magnitude [rad^2/Hz]")
        self.graphD.setAxisScaleEngine(Qwt5.QwtPlot.yLeft, Qwt5.QwtLog10ScaleEngine())
        self.graphD.setAxisScale(Qwt5.QwtPlot.yLeft, 1e-10, 1e4)

        self.graphD.setCanvasBackground(Qt.QColor(0,0,0))
        
        timerPeriod_secs = 0.005

        self.timer = QtCore.QTimer(self)
        self.timer.timeout.connect(self.update)
        self.timer.start(round(1000*timerPeriod_secs))
                
    def update(self):




        if self.isEnabled() and self.dev.bConnected:

            if self.calc.isReady:            
            
                self.curve1.setData(self.calc.IQ_i_real, self.calc.IQ_i_imag)
                self.curve2.setData(self.calc.IQ_o_real, self.calc.IQ_o_imag)
                self.graphA.replot()
    
                self.curve3.setData(self.calc.time_axis, self.calc.IQ_o_angle*(2.0*numpy.pi/4294967296.0))
                self.graphB.replot()
    
                self.curve4.setData(self.calc.time_axis, self.calc.loop_filter)
                self.graphC.replot()
    
                self.curve5.setData(self.calc.freq_axis, self.calc.spectrum)
                self.graphD.replot()


    def update_content(self):
        pass
        
