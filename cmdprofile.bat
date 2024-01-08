@echo off 

dir
TITLE %CD%

IF EXIST "C:\Program Files\Git\bin" SET PATH=%PATH%;"C:\Program Files\Git\bin"

doskey npp="C:\Program Files\Notepad++\notepad++.exe" $*

doskey cd=cd $* $T$T dir $T$T TITLE %%CD%%

doskey k=kubectl $*
doskey d=docker $*

doskey ga=git add $*
doskey gp=git push $*
doskey gc=git commit -m "$*"
doskey gpl=git pull $*
doskey gs=git status $*
doskey gd=git diff $*
doskey g=git $*

doskey rebootwsl=wsl --shutdown

doskey py=python $*

doskey unelevated=cmd /min /C "set __COMPAT_LAYER=RUNASINVOKER && start """" $1"
doskey open=start "" "$*"

doskey rm=del $*

doskey killall=taskkill /f /im $*

doskey ll=dir $*
doskey ls=dir $*
doskey la=dir $*

doskey q=exit $*
