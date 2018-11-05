#!/bin/bash

if which jsonnet; then
    printf "Formatting code"
    if find . -name '*.jsonnet' | xargs jsonnet fmt -i; then
        echo ", Done"
    fi
fi

fail() {
    echo "FAILED:" $1
    exit 1
}

## Build
echo "Building"
./plantbuild build ./build.jsonnet

## Tests
for c in $(cat ./test_cases.json | jq -r '.[] | @base64'); do
    show_args=$(echo $c | base64 --decode | jq -r '.show_args')
    printf "\n\n"
    echo "Testing ./plantbuild show $show_args"
    result=$(./plantbuild show $show_args)
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
            fail "./plantbuild show $show_args"
        fi
    done
done

printf "\n"
