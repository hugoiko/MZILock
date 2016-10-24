

from PyQt4 import QtCore, Qt, QtGui, uic



class ConsoleWidget(QtGui.QWidget):
    def __init__(self):
        super(ConsoleWidget, self).__init__()
        uic.loadUi("ConsoleWidget.ui", self)