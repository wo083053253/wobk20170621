#!/bin/bash

cat $1 | awk '{print $(NF-1)}'