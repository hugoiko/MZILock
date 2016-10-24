
################################################################
## Libraries
################################################################
import sys
import os
import ctypes
from PyQt4 import QtCore, Qt, QtGui, uic

from TCPConnectionWidget import TCPConnectionWidget
from ADCControlWidget import ADCControlWidget
from ConsoleWidget import ConsoleWidget
from DynamicScriptsWidget import DynamicScriptsWidget
from UDPRedPitayaDiscovery import UDPRedPitayaDiscovery
from RedPitayaDevice import RedPitayaDevice

################################################################
## Custom MDI window that can't be closed
################################################################
class CustomQMdiSubWindow(QtGui.QMdiSubWindow):
    def closeEvent(self, event):
        event.ignore()
        self.hide()

################################################################
## This allows to redirect stdout and stderr to a widget
################################################################
class EmittingStream(QtCore.QObject):
    textWritten = QtCore.pyqtSignal(str)
    def write(self, text):
        self.textWritten.emit(str(text))
 
################################################################
## Main GUI class
################################################################
class MainWindow(QtGui.QMainWindow):
    
    ################################################################  
    # STDIO handler
    def normalOutputWritten(self, text):
        cursor = self.instConsoleWidget.textEdit.textCursor()
        cursor.movePosition(QtGui.QTextCursor.End)
        cursor.insertText(text)
        self.instConsoleWidget.textEdit.setTextCursor(cursor)
        self.instConsoleWidget.textEdit.ensureCursorVisible()

    ################################################################
    # MdiArea Background Color
    def change_mdi_color(self, colorName):
        self.mdiArea.setBackground(QtGui.QColor(colorName))
        # self.mdiArea.repaint()
        # self.repaint()
        self.mdiArea.update()
        # self.update()
        # QtGui.QApplication.processEvents()
        # QtGui.QApplication.flush()
        # print(self.updatesEnabled())
        # print(self.mdiArea.updatesEnabled())
        # self.resize(self.size())
        for w in self.mdiArea.children():
            #w.repaint()
            w.update()

    ################################################################
    # Constructor
    def __init__(self, parent=None, bRedirectStdio=True):
        # Run parent constructor
        super(MainWindow, self).__init__(parent)
        # Create layout and controls using QtDesigner file
        uic.loadUi("MainWindow.ui", self)

        self.defaultTitle = self.windowTitle()
        self.defaultColor = '#A0A0A0'

        # List of widgets that are only enabled when connected to the FPGA
        self.controlWidgetsFPGA = list()

        self.UDPDiscovery = UDPRedPitayaDiscovery()
        self.UDPDiscovery.startListening()

        self.dev = RedPitayaDevice()
        

        ################################################################
        ## Serial connection widget
        self.instTCPConnectionWidget = TCPConnectionWidget(self, self.UDPDiscovery, self.dev)
        self.controlWidgetsFPGA.append(self.instTCPConnectionWidget)
        icon = QtGui.QIcon('icons/serial.png')
        subWin1 = CustomQMdiSubWindow()
        subWin1.setWidget(self.instTCPConnectionWidget)
        subWin1.setWindowIcon(icon)
        self.mdiArea.addSubWindow(subWin1)
        self.actionSerialConnection.triggered.connect(lambda: self.show_subwin(subWin1))
        self.actionSerialConnection.setIcon(icon)
        #subWin1.hide()
    
        ################################################################
        ## ADC control widget
        self.instADCControlWidget = ADCControlWidget(self, self.dev)
        self.controlWidgetsFPGA.append(self.instADCControlWidget)
        icon = QtGui.QIcon('icons/adc.png')
        subWin2 = CustomQMdiSubWindow()
        subWin2.setWidget(self.instADCControlWidget)
        subWin2.setWindowIcon(icon)
        self.mdiArea.addSubWindow(subWin2)
        self.actionADCControl.triggered.connect(lambda: self.show_subwin(subWin2))
        self.actionADCControl.setIcon(icon)
        #subWin2.hide()
        
        ################################################################
        ## Dynamic scripts
        self.instDynamicScriptsWidget = DynamicScriptsWidget(self, self.dev)
        self.controlWidgetsFPGA.append(self.instDynamicScriptsWidget)
        icon = QtGui.QIcon('icons/scripts.png')
        subWin8 = CustomQMdiSubWindow()
        subWin8.setWidget(self.instDynamicScriptsWidget)
        subWin8.setWindowIcon(icon)
        self.mdiArea.addSubWindow(subWin8)
        self.actionDynamicScripts.triggered.connect(lambda: self.show_subwin(subWin8))
        self.actionDynamicScripts.setIcon(icon)
        #subWin8.hide()
        

        ################################################################
        ## Console widget
        self.instConsoleWidget = ConsoleWidget()
        icon = QtGui.QIcon('icons/console.png')
        subWin0 = CustomQMdiSubWindow()
        subWin0.setWidget(self.instConsoleWidget)
        subWin0.setWindowIcon(icon)
        self.mdiArea.addSubWindow(subWin0)
        self.actionConsole.triggered.connect(lambda: self.show_subwin(subWin0))
        self.actionConsole.setIcon(icon)
        # subWin0.hide()

        # Redirect STDIO
        if bRedirectStdio:
            sys.stdout = EmittingStream(textWritten=self.normalOutputWritten)
            sys.stderr = EmittingStream(textWritten=self.normalOutputWritten)
            
        
        ################################################################
        ## About and documentation
        self.actionAbout.triggered.connect(self.showAbout)
        self.actionDocumentation.triggered.connect(self.showDocumentation)
        
        self.update_widgets_connection_status(False)

        self.change_mdi_color(self.defaultColor)

     
    ################################################################
    ## Show about dialog box
    def showAbout(self):
        QtGui.QMessageBox.about(self, "About", "")
     
    ################################################################
    ## Show documentation
    def showDocumentation(self):
        os.startfile("test.pdf")
     
    ################################################################
    ## Show and focus a MDI subwindow
    def show_subwin(self, window):
        window.show()
        window.raise_()
        window.setFocus()
     
    ################################################################
    ## Update the connection status of all widgets
    def update_widgets_connection_status(self, bConnected):
        for widget in self.controlWidgetsFPGA:
            widget.update_connection_status(bConnected)
     
    ################################################################
    ## Update the content of all widgets
    def update_widgets_content(self):
        for widget in self.controlWidgetsFPGA:
            widget.update_content()
     
    ################################################################
    ## Disconnect on close
    def closeEvent(self, event):
        if self.dev.bConnected:
            self.dev.CloseTCPConnection()
        self.UDPDiscovery.stopListening()
        
        
################################################################
## Main code
################################################################
def main():

    app = QtGui.QApplication(sys.argv)  
    bRedirectStdio = False
      
    GUI = MainWindow(bRedirectStdio=bRedirectStdio)
    # Show GUI
    # GUI.show()
    GUI.showMaximized()
    
    # Set program icon
    # hack for win7
    APPID = u'TITLE'
    ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID(APPID)
    icon = QtGui.QIcon('icons/poutine.png')
    app.setWindowIcon(icon)
    GUI.setWindowIcon(icon)
        
    # Execute application
    app.exec_()
    
    # Restore sys.stdout
    if bRedirectStdio:
        sys.stdout = sys.__stdout__
        sys.stderr = sys.__stderr__


    print("Exiting")
    
if __name__ == '__main__':
    main()
    