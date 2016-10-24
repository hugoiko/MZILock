import sys

from PyQt4 import QtCore, Qt, QtGui, uic, Qwt5
import pyqtgraph
import numpy
from RedPitayaDevice import RedPitayaDevice

from ControlWidget import ControlWidget

import time
  
class ADCControlWidget(ControlWidget):
    def __init__(self, parent, dev):
        super(ADCControlWidget, self).__init__(parent)
        uic.loadUi("ADCControlWidget.ui", self)
        self.dev = dev

        self.curve1 = pyqtgraph.PlotDataItem()
        self.curve2 = pyqtgraph.PlotDataItem()
        #self.curve1 = pyqtgraph.ScatterPlotItem()
        #self.curve1.setSize(1)
        #self.curve1.setPen(None)
        self.curve1.setPen(color='#00FFFF')
        self.curve2.setPen(color='#FF00FF')
        #self.curve1.setBrush(None)
        #self.curve1.setSymbol(None)
        self.plot1 = self.graph.addPlot(row=0, col=0, colspan=1, rowspan=1)
        self.plot1.addItem(self.curve1)
        self.plot1.addItem(self.curve2)
        self.plot1.setLabel('left','Q [V]')
        self.plot1.setLabel('bottom','I [V]')
        self.plot1.setXRange(min=-32768,max=32767)
        self.plot1.setYRange(min=-32768,max=32767)
        self.plot1.setAspectLocked(lock=True, ratio=1)
        self.curve1.setData(x=[],y=[])
        self.curve2.setData(x=[],y=[])


        self.plot2 = self.graph.addPlot(row=0, col=1, colspan=1, rowspan=1)
        self.plot3 = self.graph.addPlot(row=1, col=0, colspan=2, rowspan=1)


        self.curve4 = pyqtgraph.PlotDataItem()
        self.plot3.addItem(self.curve4)

        self.plot3.setLogMode(x=True)

        self.matrix_of_sums = numpy.zeros((5, 5))
        self.vector_of_sums = numpy.zeros((5, 1))

        # self.curve1 = Qwt5.QwtPlotCurve("Test")
        # self.curve1.setPen(Qt.QColor(0,128,0))
        # self.curve1.attach(self.graph)
        # self.curve1.setData([], [])
        # self.graph.replot()
        # self.graph.setAxisScale(Qwt5.QwtPlot.xBottom, -32768, 32767)
        # self.graph.setAxisScale(Qwt5.QwtPlot.yLeft, -32768, 32767)
        # self.graph.setCanvasBackground(Qt.QColor(255,255,255))
        
        timerPeriod_secs = 0.03

        self.timer = QtCore.QTimer(self)
        self.timer.timeout.connect(self.update)
        self.timer.start(round(1000*timerPeriod_secs))
                
    def update(self):

        # %% The fit equation is:
        # % axx + 2bxy + cyy + 2dx + 2fy + g = 0, with g = 1
        # % We construct and solve the following system of equations. It is
        # % derived from nulling the partial derivatives of the sum of squared
        # % errors.
        # %
        # %  sum(xxxx)a + sum(2xxxy)b +  sum(xxyy)c + sum(2xxx)d + sum(2xxy)f =  -sum(xx)
        # % sum(2xxxy)a + sum(4xxyy)b + sum(2xyyy)c + sum(4xxy)d + sum(4xyy)f = -sum(2xy)
        # %  sum(xxyy)a + sum(2xyyy)b +  sum(yyyy)c + sum(2xyy)d + sum(2yyy)f =  -sum(yy)
        # %  sum(2xxx)a +  sum(4xxy)b +  sum(2xyy)c +  sum(4xx)d +  sum(4xy)f =  -sum(2x)
        # %  sum(2xxy)a +  sum(4xyy)b +  sum(2yyy)c +  sum(4xy)d +  sum(4yy)f =  -sum(2y)
        # %


        if self.isEnabled() and self.dev.bConnected:
            ta = time.clock()
            self.dev.write_Zynq_register_int32(0x00040, 10000)
            self.dev.write_Zynq_register_int32(0x00044, 200)
            self.dev.write_Zynq_register_int32(0x00048, 4534)
            self.dev.write_Zynq_register_int32(0x0004C, 0)
            self.dev.write_Zynq_register_int32(0x00050, 452)
            self.dev.write_Zynq_register_int32(0x00054, 7254)
            #self.dev.write_Zynq_register_uint32(0x0007C, 1)
            #self.dev.write_Zynq_register_uint32(0x00000, 0)
            #ret = self.dev.read_Zynq_register_uint32(0x0307C)
            #print(ret)
            self.dev.write_Zynq_register_uint32(0x0007C, 1)
            #ret = self.dev.read_Zynq_register_uint32(0x0307C)
            ret = self.dev.read_Zynq_buffer_int16(0x01000, 2048)
            tb = time.clock()
            Idata = numpy.atleast_2d(ret[0::2]).T.astype(numpy.double)
            Qdata = numpy.atleast_2d(ret[1::2]).T.astype(numpy.double)
            self.curve1.setData(x=Idata[:,0], y=Qdata[:,0])
            #self.curve1.setData(Idata, Qdata)
            #self.graph.replot()
            tc = time.clock()

            # Update the sums 
            IdataNorm = Idata / 2**16
            QdataNorm = Qdata / 2**16

            Dat = numpy.concatenate((IdataNorm*IdataNorm,2*IdataNorm*QdataNorm,QdataNorm*QdataNorm,2*IdataNorm,2*QdataNorm), axis=1);
            
            # This is the matrix on the LHS
            Alinsolve = Dat.T.dot(Dat)
            # This is the column vector on the RHS
            Dlinsolve = numpy.atleast_2d(-numpy.sum(Dat, axis=0)).T
            # We solve the system

            alph = 0.01

            self.matrix_of_sums = (1-alph)*self.matrix_of_sums + alph*Alinsolve
            self.vector_of_sums = (1-alph)*self.vector_of_sums + alph*Dlinsolve


            X = numpy.linalg.solve(self.matrix_of_sums, self.vector_of_sums)

            a = X[0,0]
            b = X[1,0]
            c = X[2,0]
            d = X[3,0]
            f = X[4,0]
            g = 1.0

            x0 = (c*d-b*f)/(b*b-a*c)
            y0 = (a*f-b*d)/(b*b-a*c)

            aprimesq = ( 2.0*(a*f*f+c*d*d+g*b*b-2.0*b*d*f-a*c*g) ) / ( (b*b-a*c)*(+numpy.sqrt((a-c)*(a-c)+4.0*b*b)-(a+c)) )
            bprimesq = ( 2.0*(a*f*f+c*d*d+g*b*b-2.0*b*d*f-a*c*g) ) / ( (b*b-a*c)*(-numpy.sqrt((a-c)*(a-c)+4.0*b*b)-(a+c)) )

            aprime = numpy.sqrt( aprimesq )
            
            bprime = numpy.sqrt( bprimesq )

            if a < c:
                theta = numpy.arctan((2.0*b)/(a-c))/2.0
            else:
                theta = numpy.pi/2.0 + numpy.arctan((2.0*b)/(a-c))/2.0
            
            Brot = numpy.array([[numpy.cos(theta), numpy.sin(theta)], [numpy.sin(-theta), numpy.cos(theta)]])
            Bstr = numpy.array([[1.0/aprime,0.0],[0.0,1.0/bprime]])
            A = Bstr.dot(Brot)
            B = A.dot(numpy.array([[-x0], [-y0]]))


            arrayIn = numpy.concatenate((IdataNorm, QdataNorm), axis=1).T;
            arrayOut = 30000.0*( A.dot(arrayIn)+numpy.tile(B,(1,arrayIn.shape[1])) ).T

            IdataOut = arrayOut[:,0]
            QdataOut = arrayOut[:,1]


            self.curve2.setData(x=IdataOut, y=QdataOut)
            print(IdataOut, QdataOut)


            # F = 20*numpy.log10(numpy.absolute(numpy.fft.fft(Idata[:,0]*numpy.hamming(1024))))
            # Ax = (1024+numpy.arange(1024))/1024.0*125.0


            # self.curve4.setData(x=Ax,y=F)


    def update_content(self):
        pass
        

def main():
    
    dev = RedPitayaDevice()
    dev.OpenTCPConnection("192.168.0.105")    
    
    app = QtGui.QApplication(sys.argv)  
    wid = ADCControlWidget(None, dev)
    wid.show()
    app.exec_()
    
    
    dev.CloseTCPConnection()

if __name__ == '__main__':
    main()

    
