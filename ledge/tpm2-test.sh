#!/bin/sh -
which lava-test-case > /dev/null 2>&1
lava_test_case="$?"

cd ./tpm2-tools/test/system
./test.sh -p | tr -d '-' | tr -d '\\' | tr -d '|' | tr -d '/' | sed -e "s|\[0m||g" -e "s|\[1;33m||g" -e "s|\[1;32m||g" -e "s|\[1;31m||g" | tee tpm2-tools.log

while read -r line; do
	if echo "${line}" | egrep -iq ".* +(PASSED|FAILED)$"; then
		test="$(echo "${line}" | awk '{print $1}')"
		result="$(echo "${line}" | sed -e 's|PASSED|pass|g' -e 's|FAILED|fail|g'| awk '{print $3}')"
		if [ "${lava_test_case}" -eq 0 ]; then
			lava-test-case "${test}" --result "${result}"
		else
			echo "<TEST_CASE_ID=${test} RESULT=${result}>"
		fi
	fi
done < tpm2-tools.log

