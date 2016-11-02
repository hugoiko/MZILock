import numpy
import sys
import time

class MZILockLiveCalc:

    def __init__(self, dev):
        self.dev = dev

        self.IQ_i_real = None
        self.IQ_i_imag = None
        self.IQ_o_real = None
        self.IQ_o_imag = None

        self.IQ_o_angle = None
        self.time_axis = None

        self.loop_filter = None

        self.spectrum = None
        self.freq_axis = None

        self.IQ_cal_Bvect1 = 0
        self.IQ_cal_Bvect2 = 0
        self.IQ_cal_Amat11 = 0
        self.IQ_cal_Amat21 = 0
        self.IQ_cal_Amat12 = 0
        self.IQ_cal_Amat22 = 0

        self.UNITY_GAIN = 2**12
        self.NORMALIZATION = 2**16

        self.FS = 125e6
        self.DECIM = 2**4
        self.FILT = 2**(2+4)
        self.TEMP = self.FILT / self.DECIM

        self.IQ_cal_counter = 0
        self.IQ_cal_iterations = 0
        self.matrix_of_sums = numpy.zeros((5, 5))
        self.vector_of_sums = numpy.zeros((5, 1))

        self.isReady = False

    def start_IQ_cal(self, iterations):
        self.IQ_cal_counter = 0
        self.IQ_cal_iterations = iterations
        self.matrix_of_sums = numpy.zeros((5, 5))
        self.vector_of_sums = numpy.zeros((5, 1))

    def update_IQ_cal_sums(self, IQ_i_real, IQ_i_imag):

        IdataNorm = numpy.atleast_2d(IQ_i_real).T / (self.NORMALIZATION)
        QdataNorm = numpy.atleast_2d(IQ_i_imag).T / (self.NORMALIZATION)

        Dat = numpy.concatenate((IdataNorm*IdataNorm,2*IdataNorm*QdataNorm,QdataNorm*QdataNorm,2*IdataNorm,2*QdataNorm), axis=1);
        
        # This is the matrix on the LHS
        current_matrix = Dat.T.dot(Dat)
        # This is the column vector on the RHS
        current_vector = numpy.atleast_2d(-numpy.sum(Dat, axis=0)).T
        # We solve the system

        self.matrix_of_sums = self.matrix_of_sums + current_matrix
        self.vector_of_sums = self.vector_of_sums + current_vector

    def compute_IQ_cal_from_sums(self):

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
        # B = A.dot(numpy.array([[-x0], [-y0]]))
        B = numpy.array([[-x0], [-y0]])

        A[numpy.isnan(A)] = 0.0
        B[numpy.isnan(B)] = 0.0


        self.IQ_cal_Bvect1 = int(round((self.NORMALIZATION)*B[0,0]))
        self.IQ_cal_Bvect2 = int(round((self.NORMALIZATION)*B[1,0]))
        self.IQ_cal_Amat11 = int(round((self.UNITY_GAIN)*A[0,0]/4.0))
        self.IQ_cal_Amat21 = int(round((self.UNITY_GAIN)*A[1,0]/4.0))
        self.IQ_cal_Amat12 = int(round((self.UNITY_GAIN)*A[0,1]/4.0))
        self.IQ_cal_Amat22 = int(round((self.UNITY_GAIN)*A[1,1]/4.0))

    def data_loop(self):

        acq_started = self.dev.read_Zynq_register_uint32(0x0307C)
        if bool(acq_started):
            return

        Npoints = 1024

        ret_IQ_i = self.dev.read_Zynq_buffer_int16(0x04000, 2*Npoints)
        ret_IQ_o = self.dev.read_Zynq_buffer_int16(0x05000, 2*Npoints)
        ret_IQ_a = self.dev.read_Zynq_buffer_int32(0x06000, Npoints)
        ret_lf = self.dev.read_Zynq_buffer_int16(0x07000, 2*Npoints)

        self.IQ_i_real = ret_IQ_i[1::2].astype(numpy.double)
        self.IQ_i_imag = ret_IQ_i[0::2].astype(numpy.double)
        self.IQ_o_real = ret_IQ_o[1::2].astype(numpy.double)
        self.IQ_o_imag = ret_IQ_o[0::2].astype(numpy.double)

        self.IQ_o_angle = ret_IQ_a.astype(numpy.double)
        self.time_axis = numpy.arange(Npoints)

        Nfinal = Npoints#(Npoints/2/self.TEMP)

        self.spectrum = numpy.absolute(numpy.fft.fft(self.IQ_o_angle*(2.0*numpy.pi/4294967296.0), Npoints))**2
        self.spectrum = self.spectrum[0:Nfinal]
        self.freq_axis = float(self.FS)*numpy.arange(Nfinal).astype(numpy.double)/float(Npoints*self.DECIM)
        self.spectrum = (1.0/float(Npoints)) * self.spectrum * (((numpy.pi*float(self.FILT)*self.freq_axis/float(self.FS)) / numpy.sin((numpy.pi*self.FILT*self.freq_axis/self.FS)))**2.0)


        #print(self.spectrum)
        #print(self.freq_axis)


        self.loop_filter = ret_lf[1::2].astype(numpy.double)

        if self.IQ_cal_counter < self.IQ_cal_iterations:
            self.update_IQ_cal_sums(self.IQ_i_real, self.IQ_i_imag)
            self.IQ_cal_counter += 1
            if self.IQ_cal_counter == self.IQ_cal_iterations:
                self.compute_IQ_cal_from_sums()

        # Start new acquisition
        self.dev.write_Zynq_register_uint32(0x0007C, 0x1)

        self.isReady = True
