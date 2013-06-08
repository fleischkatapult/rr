# default rr command
rr="rr"

# check if the user supplied a custom rr command, if so use it, otherwise use default.
# $1 is number of arguments supplied to the test script
# $2 is the rr command (if exists)
function get_rr_cmd {
	if [ "$1" -gt "0" ]; then
		rr=$2
	fi
}

# compile test
# $1 is test name
# $2 are compilation flags
function compile {
	gcc -pthread -g -m32 $1.c $2 -lrt
}

# record test. 
# $1 is test name
function record {
	LD_LIBRARY_PATH="/usr/local/lib" $rr --record $lib a.out 1> $1.out.record
}

function delay_kill {
	sig=$1; delay_secs=$2; proc=$3

	sleep $delay_secs

	pid=""
	for i in `seq 1 5`; do
		live=`ps -C $3 -o pid=`
		num=`echo -e $live | wc -w`
		if [[ $num == 1 ]]; then
			pid=$live
			break
		fi
		sleep 0.1
	done

	if [[ $num > 1 ]]; then
		echo FAILED: more than one "'$proc'" >&2
		exit 1
	elif [[ -z "$pid" ]]; then
		echo FAILED: process "'$proc'" not located >&2
		exit 1
	fi

	kill -s $sig $pid
	if [[ $? != 0 ]]; then
		echo FAILED: signal $sig not delivered to "'$proc'" >&2
		exit 1
	fi

        echo Successfully delivered signal $sig to "'$proc'"
}

# record_async_signal <signal> <delay-secs> <test>
# record $test, delivering $signal to it after $delay-secs
function record_async_signal {
	delay_kill $1 $2 a.out &
	record $3
        wait
}

# replay test. 
# $1 is test name 
# $2 are rr flags
function replay {
	LD_LIBRARY_PATH="/usr/local/lib" $rr --replay --autopilot $2 trace_0/ 1> $1.out.replay 2> $1.err.replay
}

# debug <test-name> [rr-args]
# load the "expect" script to drive replay of the recording
function debug {
	LD_LIBRARY_PATH="/usr/local/lib" python $1.py $rr --replay --dbgport=1111 $2 trace_0/
	if [[ $? == 0 ]]; then
		echo "Test '$1' PASSED"
	else
		echo "Test '$1' FAILED"
	fi
}

# check test success\failure.
# $1 is test name
function check {
	if [[ $(grep "Replayer successfully finished." $1.err.replay) == "" ]]; then
		echo "Test '$1' FAILED: error during replay:"
		echo "--------------------------------------------------"
		cat $1.err.replay
		echo "--------------------------------------------------"
	elif [[ $(diff $1.out.record $1.out.replay) != "" ]]; then
		echo "Test '$1' FAILED: output from recording different than replay"
		echo "Output from recording:"
		echo "--------------------------------------------------"
		cat $1.out.record
		echo "--------------------------------------------------"
		echo "Output from replay:"
		echo "--------------------------------------------------"
		cat $1.out.replay
		echo "--------------------------------------------------"
	else
		echo "Test '$1' PASSED"
		# test passed, OK to delete temporaries
		rm -rf $1.out.record $1.out.replay $1.err.replay
	fi
}

# cleanup.  we intentionally leave .record/.replay files around for
# developers to reference.
function cleanup {
	rm -rf a.out trace_0
        killall a.out rr > /dev/null 2>&1 
        # Clear $?; we don't care if, and in fact we're happy if, we
        # failed to kill malingerers.
        ls > /dev/null
}

# Compile $test.c, record it, then replay it (optionally with
# $rr_flags) and verify record/replay output match.
function compare_test { test=$1; rr_flags=$2;
	compile $test
	record $test
	replay $test $rr_flags
	check $test
	cleanup
}

# Compile $test.c, record it, then replay the recording using the
# "expect" script $test.py (optionally with $rr_flags), which is
# responsible for computing test pass/fail.
function debug_test { test=$1; rr_flags=$2;
	compile $test
	record $test
	debug $test
	cleanup
}

get_rr_cmd $# $1