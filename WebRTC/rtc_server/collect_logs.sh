#!/bin/bash

touch debug_hexdump

FILES=./debug_logs/*
for f in $FILES
do
    cat $f | hexdump -C >> debug_hexdump
done
