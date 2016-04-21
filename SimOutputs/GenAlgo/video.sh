#!/bin/bash
for i in {1..1127}
do
   gnuplot -e "unset key; set xrange [600000:1000000]; set yrange [0:1]; set xlabel 'popObj'; set ylabel 'occupiedObj';set datafile separator ',';  set terminal jpeg; plot 'population$i.csv' using (column(\"popObj\")):(column(\"occupiedObj\"))" > pic$i.jpeg
done

avconv  -i pic%d.jpeg -r 50 video.webm
