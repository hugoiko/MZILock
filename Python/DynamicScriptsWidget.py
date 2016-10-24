

from PyQt4 import QtCore, Qt, QtGui, uic

from ControlWidget import ControlWidget

import imp
import re
  
class DynamicScriptsWidget(ControlWidget):
    def __init__(self, parent, dev):
        super(DynamicScriptsWidget, self).__init__(parent)
        uic.loadUi("DynamicScriptsWidget.ui", self)
        
        self.parent     = parent
        self.dev = dev
        
        self.module_name = "DynamicScripts"
        self.function_pattern = "(dynamicScript_)(.*)"        
        
        self.buttonLoadScripts.clicked.connect(self.buttonLoadScripts_clicked)
        self.buttonRun.clicked.connect(self.buttonRun_clicked)
        
        self.funcs = list()
        self.func_names = list()
        
    def loadScripts(self):
        (f, path, desc) = imp.find_module(self.module_name)
        try:
            module = imp.load_module(self.module_name, f, path, desc)
        except ImportError:
             return False
        finally:
            if f:
                f.close()
           
        old_name = ""
        if len(self.func_names) > 0:
            old_name = self.func_names[self.listScripts.currentRow()]
             
        names = dir(module)
        self.funcs = list()
        self.func_names = list()
        for name in names:
            m = re.match(self.function_pattern, name)
            if m is not None:
                func = getattr(module, name)
                self.funcs.append(func)
                self.func_names.append(m.groups()[1])
                
        
        self.listScripts.clear()
        new_index = -1
        for i in range(len(self.funcs)):
            self.listScripts.addItem(self.func_names[i])
            if self.func_names[i] == old_name:
                new_index = i
        if new_index != -1:
            self.listScripts.setCurrentRow(new_index)
            
        return True
        
    def buttonRun_clicked(self):
        name = self.func_names[self.listScripts.currentRow()]
        self.loadScripts()
        if name in self.func_names:
            index = self.func_names.index(name)
            self.funcs[index](self)
        
    def buttonLoadScripts_clicked(self):
        self.loadScripts()
        
    
    def update_content(self):
        self.loadScripts()
        