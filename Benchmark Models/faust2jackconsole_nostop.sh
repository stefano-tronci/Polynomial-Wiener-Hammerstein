#! /bin/bash -e

#####################################################################
#                                                                   #
#               Compiles Faust programs to JACK-console             #
#               (c) Grame, 2009-2018                                #
#                                                                   #
#####################################################################

. faustpath
. faustoptflags

CXX=g++
CXXFLAGS=$MYGCCFLAGS

ARCHFILE=$FAUSTARCH/jack-console.cpp

OSCDEFS=""
NVOICES=-1

# Check Darwin specifics
#
if [[ $(uname) == Darwin ]]; then
    ARCHLIB+=" -framework CoreMIDI -framework CoreFoundation"
else
    ARCHLIB+=" `pkg-config --cflags --libs alsa`"
fi

#-------------------------------------------------------------------
# Analyze command arguments :
# faust options                 -> OPTIONS
# if -omp : -openmp or -fopenmp -> OPENMP
# existing *.dsp files          -> FILES
#

# PHASE 1 : Look for -icc option to force use of intel icc (actually icpc)
# without having to configure CXX and CXXFLAGS

for p in $@; do
	if [ "$p" = -icc ]; then
		CXX=icpc
		CXXFLAGS=$MYICCFLAGS
    fi
done

#PHASE 2 : dispatch command arguments
while [ $1 ]
do
    p=$1

    if [ $p = "-help" ] || [ $p = "-h" ]; then
        echo "faust2jackconsole [-httpd] [-osc] [additional Faust options (-vec -vs 8...)] <file.dsp>"
        echo "Use '-httpd' to activate HTTP control"
        echo "Use '-nvoices <num>' to produce a polyphonic self-contained DSP with <num> voices, ready to be used with MIDI or OSC"
        echo "Use '-midi' to activate MIDI control"
        echo "Use '-osc' to activate OSC control"
    	exit
    fi
    if [ "$p" = -omp ]; then
        if [[ $CXX == "icpc" ]]; then
            OMP="-openmp"
        else
            OMP="-fopenmp"
        fi
    fi
  
    if [ "$p" = -icc ]; then
    	ignore=" "
    elif [ $p = "-osc" ]; then
        OSCDEFS="-DOSCCTRL -lOSCFaust"
    elif [ $p = "-httpd" ]; then
        HTTPDEFS="-DHTTPCTRL -lHTTPDFaust -lmicrohttpd"
    elif [ $p = "-nvoices" ]; then
        shift
        NVOICES=$1
        if [ $NVOICES -ge 0 ]; then
            CXXFLAGS="$CXXFLAGS -DNVOICES=$NVOICES"
        fi
    elif [ $p = "-midi" ]; then
        MIDIDEFS="-DMIDICTRL"
    elif [ $p = "-arch32" ]; then
        PROCARCH="-m32 -L/usr/lib32"
    elif [ $p = "-arch64" ]; then
        PROCARCH="-m64"
    elif [ ${p:0:1} = "-" ]; then
	    OPTIONS="$OPTIONS $p"
	elif [[ -f "$p" ]]; then
	    FILES="$FILES $p"
	else
	    OPTIONS="$OPTIONS $p"        
	fi
	
shift

done
	
#-------------------------------------------------------------------
# compile the *.dsp files using ALSA and GTK on linux
#
for f in $FILES; do
	
	# compile faust to c++
	faust -t 0 -i -a $ARCHFILE $OPTIONS "$f" -o "$f.cpp" || exit

	# compile c++ to binary
	(
		#$CXX $CXXFLAGS $FAUSTTOOLSFLAGS $OMP "$f.cpp" -I/usr/local/include -L/usr/local/lib `pkg-config --cflags --libs jack sndfile` $PROCARCH $OSCDEFS $HTTPDEFS -o "${f%.dsp}"
		$CXX $CXXFLAGS $FAUSTTOOLSFLAGS $OMP "$f.cpp" -I/usr/local/include -L/usr/local/lib `pkg-config --cflags --libs jack` $PROCARCH $OSCDEFS $HTTPDEFS $MIDIDEFS $ARCHLIB -lpthread -o "${f%.dsp}"
	) > /dev/null || exit
	rm "$f.cpp"

	# collect binary file name for FaustWorks
	BINARIES="$BINARIES${f%.dsp};"
done

echo $BINARIES
