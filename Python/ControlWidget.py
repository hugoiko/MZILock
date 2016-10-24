    
from PyQt4 import QtCore, Qt, QtGui, uic

class ControlWidget(QtGui.QWidget):
    
    def __init__(self, parent=None):
        super(ControlWidget, self).__init__(parent)
        self.parent = parent
        
    def update_content(self):
        pass
    
    def update_connection_status(self, bConnected):
        self.setEnabled(bConnected)
    
    def ibus_write(self, address, data_bytes):
        return self.parent.ibus_write(address, data_bytes)
        
    def ibus_read(self, address, byte_count=8):
        return self.parent.ibus_read(address, byte_count)
        
    def ibus_flush(self):
        return self.parent.ibus_flush()
        
    def update_all_other_widgets(self):
        self.parent.update_widgets_content()
        