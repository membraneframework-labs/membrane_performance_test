
for ITER in 1
do
    mix performance_test --mode autodemand --numberOfElements 30 --howManyTries 3 --tick 10000 --reductions 1000 --initalGeneratorFrequency $((2500*$ITER)) --chosenMetrics passing_time_avg,passing_time_std,throughput --shouldAdjustGeneratorFrequency --shouldProducePlots --shouldProvideMetricsHeader /project/some_test_result_dir/which_probably/doesnt_even_exist
done 