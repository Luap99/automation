#!/bin/bash

source $(dirname ${BASH_SOURCE[0]})/testlib.sh || exit 1
source "$TEST_DIR"/"$SUBJ_FILENAME" || exit 2

test_message_text="This is the test text for a console_output library unit-test"

basic_tests() {
    local _fname=$1
    local _exp_exit=$2
    local _exp_word=$3

    [[ "$_fname" == "dbg" ]] || \
        test_cmd "At least 5-stars are shown on call to $_fname function" \
            $_exp_exit "\*{5}" \
            $_fname "$test_message_text"

    test_cmd "The word '$_exp_word' appears on call to $_fname function" \
        $_exp_exit "$_exp_word" \
        $_fname "$test_message_text"

    test_cmd \
        "A default message is shown when none provided" \
        $_exp_exit "$_exp_word.+\w+" \
        $_fname

    test_cmd "The message text appears on call to $_fname message" \
        $_exp_exit "$test_message_text" \
        $_fname "$test_message_text"

    test_cmd "The message text includes a the file, line number and testing function reference" \
        $_exp_exit '\.sh:[[:digit:]]+ in .+\(\)' \
        $_fname "$test_message_text"
}

for fname in warn die; do
    exp_exit=0
    exp_word="WARNING"
    if [[ "$fname" == "die" ]]; then
        exp_exit=1
        exp_word="ERROR"
    fi
    basic_tests $fname $exp_exit $exp_word
done

# Function requires stdin, must execute in subshell by test_cmd
export -f indent
# test_cmd whitespace-squashes output but this function's purpose is producing whitespace
EXPECTED_SUM="63d43cf4cbc95b61754d57e9c877a082eab24ba89a8628825e7d8006a0af34ad"
test_cmd "The indent function correctly indents 4x number of spaces indicated" \
    0 "$EXPECTED_SUM" \
    bash -c 'echo "The quick brown fox jumped to the right 16-spaces" | indent 4 | sha256sum'

test_cmd "The indent function notices when no arguments are given" \
    1 "number greater than 1" \
    indent

test_cmd "The indent function notices when a non-number is given" \
    1 "number greater than 1.*foobar" \
    indent foobar

DEBUG=0
test_cmd \
    "The dbg function has no output when \$DEBUG is zero and no message is given" \
    0 "" \
    dbg

test_cmd \
    "The dbg function has no output when \$DEBUG is zero and a test message is given" \
    0 "" \
    dbg "$test_message_text"

DEBUG=1
basic_tests dbg 0 DEBUG
DEBUG=0

export VAR1=foo VAR2=bar VAR3=baz
test_cmd \
    "The req_env_vars function has no output for all non-empty vars" \
    0 "" \
    req_env_vars VAR1 VAR2 VAR3

unset VAR2
test_cmd \
    "The req_env_vars function catches an empty VAR2 value" \
    1 "Environment variable 'VAR2' is required" \
    req_env_vars VAR1 VAR2 VAR3

VAR1="    
     "
test_cmd \
    "The req_env_vars function catches a whitespace-full VAR1 value" \
    1 "Environment variable 'VAR1' is required" \
    req_env_vars VAR1 VAR2 VAR3

unset VAR1 VAR2 VAR3
test_cmd \
    "The req_env_vars function shows the source file/function of caller and error" \
    1 "testlib.sh:test_cmd()" \
    req_env_vars VAR1 VAR2 VAR3

unset SECRET_ENV_RE
test_cmd \
    "The show_env_vars function issues warning when \$SECRET_ENV_RE is unset/empty" \
    0 "SECRET_ENV_RE var. unset/empty" \
    show_env_vars

export UPPERCASE="@@@MAGIC@@@"
export super_secret="@@@MAGIC@@@"
export nOrMaL_vAr="@@@MAGIC@@@"
for var_name in UPPERCASE super_secret nOrMaL_vAr; do
    test_cmd \
        "Without secret filtering, expected $var_name value is shown" \
        0 "${var_name}=${!var_name}" \
        show_env_vars
done

export SECRET_ENV_RE='(.+SECRET.*)|(uppercase)|(mal_var)'
TMPFILE=$(mktemp -p '' ".$(basename ${BASH_SOURCE[0]})_tmp_XXXX")
#trap "rm -f $TMPFILE" EXIT  # FIXME
( show_env_vars 2>&1 ) >> "$TMPFILE"
test_cmd \
    "With case-insensitive secret filtering, no magic values shown in output" \
    1 ""\
    grep -q 'UPPERCASE=@@@MAGIC@@@' "$TMPFILE"

unset env_vars SECRET_ENV_RE UPPERCASE super_secret nOrMaL_vAr

# script is set +e
exit_with_status
