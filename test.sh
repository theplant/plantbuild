#!/bin/bash

# Run the test cases with jsonnet against ./jsonnetlib, with the same
# arguments that entry.sh gives in the plantbuild image. Put jsonnet on
# PATH first.

if ! command -v jsonnet >/dev/null; then
    echo "jsonnet not found, install it from https://github.com/google/go-jsonnet/releases"
    exit 1
fi

githash7=$(git rev-parse HEAD | cut -c 1-7)

# show <jsonnet file> [-v <version>], the same as `plantbuild show`
show() {
    local file=$1 version=$githash7 opt OPTIND=1
    shift
    while getopts "v:" opt; do
        case $opt in
        v) version=$OPTARG ;;
        *) return 1 ;;
        esac
    done
    jsonnet -J jsonnetlib -V VERSION="$version" "$file"
}

fail() {
    echo "FAILED:" $1
    exit 1
}

## Tests
for c in $(cat ./test_cases.json | jq -r '.[] | @base64'); do
    show_args=$(echo $c | base64 --decode | jq -r '.show_args')
    printf "\n\n"
    echo "Testing show $show_args"
    result=$(show $show_args)
    for assert in $(echo $c | base64 --decode | jq -r '.asserts[] | @base64'); do
        jq_path=$(echo $assert | base64 --decode | jq -r '.jq_path')
        expected=$(echo $assert | base64 --decode | jq -r '.expected')
        actual=$(printf "$result" | jq -r "$jq_path")
        expected=$(eval "printf \"$expected\"")
        if diff -B <(printf "$actual\n") <(printf "$expected\n"); then
            printf "."
        else
            printf "$result"
            printf "\n==jq_path==\n$jq_path\n"
            printf "\n==expected==\n$expected\n"
            printf "\n==actual==\n$actual\n"
            diff -B <(printf "$actual\n") <(printf "$expected\n")
            fail "show $show_args"
        fi
    done
done

printf "\n"
