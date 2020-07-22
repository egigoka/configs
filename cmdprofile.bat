@echo off 
doskey k=kubectl $*
doskey d=docker $*
doskey gp=git pull
doskey gc=git commit -a -m "$*"

doskey killall=taskkill /f /im $*
doskey py=python $*
doskey open=start "" "$*"

doskey rm=del $*