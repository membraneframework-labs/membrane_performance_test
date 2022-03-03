
for ITER in 1
do
    mix performance_test --mode autodemand --n 30 --howManyTries 3 --tick 10000 --reductions 1000 --initalGeneratorFrequency $((2500*$ITER)) --chosenMetrics generator_frequency,throughput,passing_time_avg,passing_time_std --shouldProducePlots --shouldProvidemetricsHeader /project/results/
done 