@echo off 
doskey k=kubectl $*
doskey d=docker $*

doskey ga=git add $*
doskey gp=git pull
doskey gc=git commit -a -m "$*"

doskey py=python $*

doskey unelevated=cmd /min /C "set __COMPAT_LAYER=RUNASINVOKER && start "" %1"
doskey open=start "" "$*"

doskey rm=del $*
doskey killall=taskkill /f /im $*

