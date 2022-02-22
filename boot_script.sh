
for ITER in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15
do
    mix performance_test --mode push --n 30 --howManyTries 0 --tick 10000 --reductions 1000 --initalGeneratorFrequency $((2500*$ITER)) --statistics generator_frequency,throughput,avg,std /project/
done 