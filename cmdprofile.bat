@echo off 
doskey k=kubectl $*
doskey d=docker $*

doskey ga=git add $*
doskey gp=git pull
doskey gc=git commit -a -m "$*"
doskey gu=git push $*
<<<<<<< HEAD
doskey gs=git status $*
=======
doskey g=git $*
>>>>>>> dc2139b86c02bc871ea8e09e0d9acb8f90049e87

doskey py=python $*

doskey unelevated=cmd /min /C "set __COMPAT_LAYER=RUNASINVOKER && start """" $1"
doskey open=start "" "$*"

doskey rm=del $*
doskey killall=taskkill /f /im $*
doskey ll=dir $*
doskey ls=dir $*
doskey la=dir $*
