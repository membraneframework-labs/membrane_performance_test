
for ITER in 4
do
    mix performance_test --mode autodemand --n 30 --howManyTries 5 --tick 10000 --initalGeneratorFrequency $((2500*$ITER)) --shouldAdjustGeneratorFrequency --shouldProducePlots --shouldProvideStatisticsHeader --statistics generator_frequency,tries_counter,throughput,avg /project/
done 