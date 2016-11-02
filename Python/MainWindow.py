
################################################################
## Libraries
################################################################
import sys
import os
import ctypes
from PyQt4 import QtCore, Qt, QtGui, uic

from TCPConnectionWidget import TCPConnectionWidget
from IQCalibrationWidget import IQCalibrationWidget
from VisualizationWidget import VisualizationWidget
from LoopFilterWidget import LoopFilterWidget
from ConsoleWidget import ConsoleWidget
from DynamicScriptsWidget import DynamicScriptsWidget
from UDPRedPitayaDiscovery import UDPRedPitayaDiscovery
from RedPitayaDevice import RedPitayaDevice
from MZILockLiveCalc import MZILockLiveCalc

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
        self.calc = MZILockLiveCalc(self.dev)

        ################################################################
        ## TCP Connection Widget
        self.instTCPConnectionWidget = TCPConnectionWidget(self, self.UDPDiscovery, self.dev)
        self.controlWidgetsFPGA.append(self.instTCPConnectionWidget)
        icon = QtGui.QIcon('icons/serial.png')
        subWin1 = CustomQMdiSubWindow()
        subWin1.setWidget(self.instTCPConnectionWidget)
        subWin1.setWindowIcon(icon)
        self.mdiArea.addSubWindow(subWin1)
        self.actionTCPConnection.triggered.connect(lambda: self.show_subwin(subWin1))
        self.actionTCPConnection.setIcon(icon)
        #subWin1.hide()
    
        ################################################################
        ## IQ Calibration Widget
        self.instIQCalibrationWidget = IQCalibrationWidget(self, self.dev)
        self.controlWidgetsFPGA.append(self.instIQCalibrationWidget)
        icon = QtGui.QIcon('icons/adc.png')
        subWin2 = CustomQMdiSubWindow()
        subWin2.setWidget(self.instIQCalibrationWidget)
        subWin2.setWindowIcon(icon)
        self.mdiArea.addSubWindow(subWin2)
        self.actionIQCalibration.triggered.connect(lambda: self.show_subwin(subWin2))
        self.actionIQCalibration.setIcon(icon)
        #subWin2.hide()

        ################################################################
        ## Visualization Widget
        self.instVisualizationWidget = VisualizationWidget(self, self.dev)
        self.controlWidgetsFPGA.append(self.instVisualizationWidget)
        icon = QtGui.QIcon('icons/adc.png')
        subWin3 = CustomQMdiSubWindow()
        subWin3.setWidget(self.instVisualizationWidget)
        subWin3.setWindowIcon(icon)
        self.mdiArea.addSubWindow(subWin3)
        self.actionVisualization.triggered.connect(lambda: self.show_subwin(subWin3))
        self.actionVisualization.setIcon(icon)
        #subWin3.hide()

        ################################################################
        ## Loop Filter Widget
        self.instLoopFilterWidget = LoopFilterWidget(self, self.dev)
        self.controlWidgetsFPGA.append(self.instLoopFilterWidget)
        icon = QtGui.QIcon('icons/adc.png')
        subWin4 = CustomQMdiSubWindow()
        subWin4.setWidget(self.instLoopFilterWidget)
        subWin4.setWindowIcon(icon)
        self.mdiArea.addSubWindow(subWin4)
        self.actionLoopFilter.triggered.connect(lambda: self.show_subwin(subWin4))
        self.actionLoopFilter.setIcon(icon)
        #subWin4.hide()
        
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
        subWin8.hide()
        

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
        #subWin0.hide()

        # Redirect STDIO
        if bRedirectStdio:
            sys.stdout = EmittingStream(textWritten=self.normalOutputWritten)
            sys.stderr = EmittingStream(textWritten=self.normalOutputWritten)
            
        
        ################################################################
        ## About and documentation
        self.actionAbout.triggered.connect(self.show_about)
        self.actionDocumentation.triggered.connect(self.show_documentation)
        
        self.update_widgets_connection_status(False)

        self.change_mdi_color(self.defaultColor)


        # ################################################################
        # ## Data Loop timer
        # timerPeriod_secs = 0.001
        # self.timer = QtCore.QTimer(self)
        # self.timer.timeout.connect(self.data_loop)
        # self.timer.start(round(1000*timerPeriod_secs))

     
    ################################################################
    ## Show about dialog box
    def show_about(self):
        QtGui.QMessageBox.about(self, "About", "")
     
    ################################################################
    ## Show documentation
    def show_documentation(self):
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
        
    # ################################################################
    # ## Data Loop
    # def data_loop(self):
    #     if not self.dev.bConnected:
    #         return
    #     self.calc.data_loop()




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

    
if __name__ == '__main__':
    main()
    