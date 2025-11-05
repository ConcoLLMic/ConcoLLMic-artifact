#!/bin/bash

## First, get the overall coverage data
lcov --capture --directory . --output-file coverage.info --rc lcov_branch_coverage=1 > /dev/null 2>&1

cov_data=$(lcov --summary coverage.info --rc lcov_branch_coverage=1 2>&1)
                
# extract the line coverage percentage (more robust version)
l_per=$(echo "$cov_data" | grep "lines" | awk '{print $2}' | tr -d '%')
# extract the absolute line coverage (more robust version)
l_abs=$(echo "$cov_data" | grep "lines" | awk '{print $3}' | tr -d '()')
# extract the branch coverage percentage (more robust version)
b_per=$(echo "$cov_data" | grep "branches" | awk '{print $2}' | tr -d '%')
# extract the absolute branch coverage (more robust version)
b_abs=$(echo "$cov_data" | grep "branches" | awk '{print $3}' | tr -d '()')

covered_times_of_line=0

## Second, get the covered times of specific line in the file if three arguments are provided
if [ $# -eq 3 ]; then
    relative_path=$1
    line_no=$2
    line_content=$3 # already stripped

    # check if relative_path exists and is a file
    if [ ! -f "$relative_path" ]; then
        echo "File $relative_path does not exist"
        exit 1
    fi

    # generate gcov file
    src_dir=$(dirname "$relative_path")
    basename=$(basename "$relative_path")
    
    cd "libsoup"

    if [[ $src_dir == "examples" ]]; then
        # e.g. examples/simple_httpd.c 
        # ---> build/examples/simple-httpd.p/simple_httpd.c.gcda
        output=$(gcov -r -b -o "../build/$src_dir/${basename%.*}.p/$basename.gcda" "$basename" 2>&1)
    
    elif [[ $src_dir == "libsoup" ]]; then
        IFS='/' read -r -a parts <<< "$src_dir" # split src_dir into parts

        if [ "${#parts[@]}" -eq 1 ]; then
            # e.g. libsoup/soup-form.c
            # ---> build/libsoup/libsoup-3.0.a.p/soup-form.c.gcda
            output=$(gcov -r -b -o "../build/libsoup/libsoup-3.0.a.p/$basename.gcda" "$basename" 2>&1)
        else
            # e.g. libsoup/http1/soup-body-input-stream.c 
            # ---> build/libsoup/libsoup-3.0.a.p/http1_soup-body-input-stream.c.gcda
            output=$(gcov -r -b -o "../build/libsoup/libsoup-3.0.a.p/${parts[1]}_${basename}.gcda" "$basename" 2>&1)
        fi
    
    else
        echo "$l_per,$l_abs,$b_per,$b_abs,$covered_times_of_line"
        exit
    fi

    gcov_file="$basename.gcov"
    if [ ! -f "$gcov_file" ]; then
        echo "GCOV file $gcov_file not found"
        exit 1
    fi
    
    # The line_no is not accurate, we should locate the exact line by looking around the given line_no using the line_content
    search_range=30
    lower_bound=$((line_no - search_range))
    upper_bound=$((line_no + search_range))

    covered_times_of_line=$(awk -v lb="$lower_bound" -v ub="$upper_bound" -v want="$line_content" '
        BEGIN {
            printed = 0
            # trim and collapse whitespaces
            gsub(/^[ \t]+|[ \t]+$/, "", want)
            gsub(/[ \t]+/, " ", want)
        }
        {
            p1 = index($0, ":")
            p2 = index(substr($0, p1 + 1), ":")
            if (!p1 || !p2)  next
            p2 += p1

            count  = substr($0, 1,  p1 - 1)
            lineno = substr($0, p1 + 1, p2 - p1 - 1) + 0
            code   = substr($0, p2 + 1)

            if (lineno >= lb && lineno <= ub) { 
                gsub(/^[ \t]+|[ \t]+$/, "", code)
                gsub(/[ \t]+/, " ", code)
                if (code == want) {
                    
                    gsub(/^[ \t]+/, "", count)
                    printed = 1 
                    if (count ~ /^[-#]/) print 0
                    else                 print count + 0
                    exit
                }
            }
            if (lineno > ub) {
                exit
            }
        }
        END { if (!printed) print 0 }
    ' "$gcov_file")   
fi

echo "$l_per,$l_abs,$b_per,$b_abs,$covered_times_of_line"