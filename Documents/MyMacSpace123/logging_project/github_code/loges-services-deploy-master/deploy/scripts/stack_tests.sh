#!/bin/bash

set -e


func_test() {
    echo "blueprint for functional testing"
}


perf_test() {
    echo "blueprint for performance testing"
}


testing_type=$1
case $testing_type in
    func*)
        echo "functional testing invoked"
        func_test
        ;;
    perf*)
        echo "performance testing invoked"
        perf_test
        ;;
    *)
        echo "usage: $0 <testing_type>"
        echo "<testing_type> can be:"
        echo "  - 'func' for functional testing"
        echo "  - 'perf' for perfomance testing"
        exit 1
esac
