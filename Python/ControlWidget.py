    
from PyQt4 import QtCore, Qt, QtGui, uic

class ControlWidget(QtGui.QWidget):
    
    def __init__(self, parent=None):
        super(ControlWidget, self).__init__(parent)
        self.parent = parent
        
    def update_content(self):
        pass
    
    def update_connection_status(self, bConnected):
        self.setEnabled(bConnected)
 
    def update_all_other_widgets(self):
        self.parent.update_widgets_content()
        