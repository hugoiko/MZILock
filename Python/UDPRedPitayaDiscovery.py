# -*- coding: utf-8 -*-
"""
Created on Thu Dec 17 17:54:31 2015

@author: JD
"""

# Simple service discovery implementation based on UDP broadcast packets:
# This class sends a UDP broadcast packet on port 1952 and then listens for replies on port 1952+1.
# Those replies do not contain useful data, other than the sender's IP addresses


import socket
import select
import time


class UDPRedPitayaDiscovery():
    
    #def __init__(self, broadcast_address="255.255.255.255", port_number=1952):
    def __init__(self, broadcast_address="255.255.255.255", port_number=1952):
        self.port_number = port_number
        self.broadcast_address = broadcast_address
        self.sock_conn = None
        self.sock_server = None
        
        self.bVerbose = True
        
        #self.startListening()


    # def __del__(self):
    #     print("Calling destructor")
    #     self.stopListening()
        
    def startListening(self):
        # Initialization:
        if self.bVerbose:
            print('Creating server socket...')
        HOST_LOCALHOST = ''       # means local host
        self.sock_server = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock_server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.sock_server.setblocking(0)
        self.sock_server.bind((HOST_LOCALHOST, self.port_number+1))
        # no need to call listen() since this is UDP

    def stopListening(self):
        if self.sock_server is not None:
            self.sock_server.shutdown(socket.SHUT_RDWR)
            self.sock_server.close()
        
        
    def send_broadcast(self):
        if self.bVerbose:
            print('Creating client socket...')
        self.sock_client = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock_client.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        self.sock_client.connect((self.broadcast_address, self.port_number))
        # send a broadcast packet:
        self.sock_client.send("")

        if self.bVerbose:
            print('Closing client socket...')
        self.sock_client.shutdown(socket.SHUT_RDWR)
        self.sock_client.close()
        
    def check_answers(self):
        # is there any data ?
        # note the [0] at the end which selects only the first output of the select()
        ready_to_read = select.select([self.sock_server], [], [], 0)[0]
        
        if ready_to_read:
            (mac_address_data, host_info) = self.sock_server.recvfrom(4096)
#            print repr(mac_address_data)
            # we don't care about the data, we are only looking for the IP addresses
            return (host_info[0], mac_address_data)
        else:
            return (None, None)


    def run_for_N_seconds(self, Timeout=1):
        if self.bVerbose:
            print('run()')
            
        # send a broadcast packet:
        self.send_broadcast()
        
        # then we check for answers:
        start_time = time.clock()
        ElapsedTime = 0
        while ElapsedTime < Timeout:
            
            (host, mac_address) = self.check_answers()
#            if not host is None:
            print (host, mac_address)
            
            time.sleep(0.1)
            ElapsedTime = time.clock() - start_time
            
            
def main():
#    disc = UDPRedPitayaDiscovery("192.168.137.255")
    disc = UDPRedPitayaDiscovery("192.168.0.255")
    disc.run_for_N_seconds(10)
#    disc.send_broadcast()
#    time.sleep(0.1)
#    print(disc.check_answers())
#    while 1:
#        time.sleep(1)
#        print(disc.check_answers())
#    
    
if __name__ == "__main__":
    main()