# -*- coding: utf-8 -*-

import socket
import struct
import time

import numpy as np

class RedPitayaDevice():

    MAGIC_BYTES_WRITE_REG           = 0xABCD1233
    MAGIC_BYTES_READ_REG            = 0xABCD1234
    MAGIC_BYTES_READ_BUFFER         = 0xABCD1235
    MAGIC_BYTES_READ_UINT32_BUFFER  = 0xABCD1335
    
    MAGIC_BYTES_WRITE_FILE          = 0xABCD1237
    MAGIC_BYTES_SHELL_COMMAND       = 0xABCD1238
    MAGIC_BYTES_REBOOT_MONITOR      = 0xABCD1239
    
    FPGA_BASE_ADDR                  = 0x40000000

    MAX_SAMPLES_READ_UINT32_BUFFER  = 1024


    def __init__(self):
        self.bConnected = False

    def open_tcp_connection(self, HOST, PORT=5000):
        self.OpenTCPConnection(HOST=HOST, PORT=PORT)

    def OpenTCPConnection(self, HOST, PORT=5000):
        self.HOST = HOST
        self.PORT = PORT
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock.setblocking(1)
        # Disable the Nagle Algorithm (TCP_NODELAY). 
        # Seems to improve real time performance but increases the total number of TCP packets
        self.sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        try:
            self.sock.connect((self.HOST, self.PORT))
            self.bConnected = True
        except socket.error, value:
            self.bConnected = False
            return value

    def close_tcp_connection(self):
        self.CloseTCPConnection()

    def CloseTCPConnection(self):
        self.sock.shutdown(socket.SHUT_RDWR)
        self.sock.close()
        self.bConnected = False

    def _recvall(self, count):
        buf = b''
        
        while count:
            newbuf = self.sock.recv(count)
            if not newbuf: return None
            buf += newbuf
            count -= len(newbuf)
            
        return buf


    # Function used to send a file write command:
    def write_file_on_remote(self, strFilenameLocal, strFilenameRemote):
        # open local file and load into memory:
        file_data = np.fromfile(strFilenameLocal, dtype=np.uint8)
        
        # send header
        packet_to_send = struct.pack('=III', self.MAGIC_BYTES_WRITE_FILE, len(strFilenameRemote), len(file_data))
        self.sock.sendall(packet_to_send)
        # send filename
        self.sock.sendall(strFilenameRemote.encode('ascii'))
        # send actual file
        self.sock.sendall(file_data.tobytes())
        
    # Function used to send a shell command to the Red Pitaya:
    def send_shell_command(self, strCommand):
        
        # send header
        packet_to_send = struct.pack('=III', self.MAGIC_BYTES_SHELL_COMMAND, len(strCommand), 0)
        self.sock.sendall(packet_to_send)
        # send filename
        self.sock.sendall(strCommand.encode('ascii'))
        
    # Function used to reboot the monitor-tcp program
    def send_reboot_command(self):
        
        # send header
        packet_to_send = struct.pack('=III', self.MAGIC_BYTES_REBOOT_MONITOR, 0, 0)
        self.sock.sendall(packet_to_send)

    #######################################################
    # Functions used to access the memory-mapped registers of the Zynq
    #######################################################

    def write_Zynq_register_uint32(self, address_uint32, data_uint32):
#        print "write_Zynq_register_uint32(): address_uint32 = %s, self.FPGA_BASE_ADDR+address_uint32 = %s, data = %d" % (hex(address_uint32), hex(self.FPGA_BASE_ADDR+address_uint32), data_uint32)
        packet_to_send = struct.pack('=III', self.MAGIC_BYTES_WRITE_REG, self.FPGA_BASE_ADDR+address_uint32, int(data_uint32) & 0xFFFFFFFF)
        self.sock.sendall(packet_to_send)

    def write_Zynq_register_int32(self, address_uint32, data_int32):
#        print "write_Zynq_register_int32(): address_uint32 = %s, self.FPGA_BASE_ADDR+address_uint32 = %s\n" % (hex(address_uint32), hex(self.FPGA_BASE_ADDR+address_uint32))
        
        packet_to_send = struct.pack('=IIi', self.MAGIC_BYTES_WRITE_REG, self.FPGA_BASE_ADDR+address_uint32, data_int32)
        self.sock.sendall(packet_to_send)

    def read_Zynq_register_uint32(self, address_uint32):
        # print "read_Zynq_register_uint32(): address_uint32 = %s, self.FPGA_BASE_ADDR+address_uint32 = %s\n" % (hex(address_uint32), hex(self.FPGA_BASE_ADDR+address_uint32))
        packet_to_send = struct.pack('=III', self.MAGIC_BYTES_READ_REG, self.FPGA_BASE_ADDR+address_uint32, 0)  # last value is reserved
        self.sock.sendall(packet_to_send)
        data_buffer = self._recvall(4)   # read 4 bytes (32 bits)
        if len(data_buffer) != 4:
            print "read_Zynq_register_uint32() Error: len(data_buffer) != 4: repr(data_buffer) = %s" % (repr(data_buffer))
        register_value_as_tuple = struct.unpack('I', data_buffer)
        return register_value_as_tuple[0]

    def read_Zynq_register_int32(self, address_uint32):
        # print "read_Zynq_register_int32(): address_uint32 = %s, self.FPGA_BASE_ADDR+address_uint32 = %s\n" % (hex(address_uint32), hex(self.FPGA_BASE_ADDR+address_uint32))
        packet_to_send = struct.pack('=III', self.MAGIC_BYTES_READ_REG, self.FPGA_BASE_ADDR+address_uint32, 0)  # last value is reserved
        self.sock.sendall(packet_to_send)
        data_buffer = self._recvall(4)   # read 4 bytes (32 bits)
        if len(data_buffer) != 4:
            print "read_Zynq_register_uint32() Error: len(data_buffer) != 4: repr(data_buffer) = %s" % (repr(data_buffer))
        register_value_as_tuple = struct.unpack('i', data_buffer)
        return register_value_as_tuple[0]

    def read_Zynq_register_uint64(self, address_uint32_lsb, address_uint32_msb):
        # print "read_Zynq_register_uint64()"
        results_lsb = self.read_Zynq_register_uint32(address_uint32_lsb)
        results_msb = self.read_Zynq_register_uint32(address_uint32_msb)

        # print 'results_lsb = %d' % results_lsb
        # print 'results_msb = %d' % results_msb

        # convert to 64 bits using numpy's casts
        results = np.array((results_lsb, results_msb), np.dtype(np.uint32))
        results = np.frombuffer(results, np.dtype(np.uint64) )

        return results

    def read_Zynq_register_int64(self, address_uint32_lsb, address_uint32_msb):
        # print "read_Zynq_register_uint64()"
        results_lsb = self.read_Zynq_register_uint32(address_uint32_lsb)
        results_msb = self.read_Zynq_register_uint32(address_uint32_msb)

        # print 'results_lsb = %d' % results_lsb
        # print 'results_msb = %d' % results_msb

        # convert to 64 bits using numpy's casts
        results = np.array((results_lsb, results_msb), np.dtype(np.uint32))
        results = np.frombuffer(results, np.dtype(np.int64) )

        return results

    def read_Zynq_buffer_char(self, address_uint32, number_of_chars):

        # Input validation
        if address_uint32 % 4:
            raise ValueError("Zynq buffer read address 0x%08X is not a multiple of 4." % (self.FPGA_BASE_ADDR+address_uint32))
        if number_of_chars % 4:
            raise ValueError("Zynq buffer read length in bytes %d is not a multiple of 4." % number_of_chars)
        if number_of_chars > 4*self.MAX_SAMPLES_READ_UINT32_BUFFER:
            raise ValueError("Zynq buffer read length exceeeds maximum: %d > %d bytes." % (number_of_chars, 4*self.MAX_SAMPLES_READ_UINT32_BUFFER))

        number_of_uint32 = number_of_chars/4
        packet_to_send = struct.pack('=III', self.MAGIC_BYTES_READ_UINT32_BUFFER, self.FPGA_BASE_ADDR+address_uint32, number_of_uint32)    # last value is reserved
        self.sock.sendall(packet_to_send)
        data_buffer = self._recvall(number_of_chars)
        return data_buffer
  
    def read_Zynq_buffer_int32(self, address_uint32, number_of_int32):
        data_buffer = self.read_Zynq_buffer_char(address_uint32, 4*number_of_int32)
        return np.fromstring(data_buffer, dtype=np.int32)
  
    def read_Zynq_buffer_uint32(self, address_uint32, number_of_uint32):
        data_buffer = self.read_Zynq_buffer_char(address_uint32, 4*number_of_uint32)
        return np.fromstring(data_buffer, dtype=np.uint32)

    def read_Zynq_buffer_int16(self, address_uint32, number_of_int16):
        data_buffer = self.read_Zynq_buffer_char(address_uint32, 2*number_of_int16)
        return np.fromstring(data_buffer, dtype=np.int16)

    def read_Zynq_buffer_uint16(self, address_uint32, number_of_uint16):
        data_buffer = self.read_Zynq_buffer_char(address_uint32, 2*number_of_uint16)
        return np.fromstring(data_buffer, dtype=np.uint16)




def main():
    dev = RedPitayaDevice()
    dev.OpenTCPConnection("192.168.0.101")
    
    #dev.write_Zynq_register_int32(0x0007C, 1)
    #for i in range(1024):
    #    dev.write_Zynq_register_int32(i*4,i)
    #rp.write_Zynq_register_int32(0x00000,143246)
    #rp.write_Zynq_register_int32(0x00FFC,143246)
    #ret = dev.read_Zynq_register_int32(0x01000)
    #print(ret)
    #ret = dev.read_Zynq_register_int32(0x01004)
    #print(ret)
    ret = dev.read_Zynq_buffer_int16(0x00000, 2048)
    print(ret)
    
    dev.CloseTCPConnection()

if __name__ == "__main__":
    main()
