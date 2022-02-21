
for ITER in 1
do
    mix performance_test --mode pull --n 30 --howManyTries 5 --tick 10000 --initalGeneratorFrequency $((2500*$ITER)) --shouldAdjustGeneratorFrequency --shouldProducePlots --shouldProvideStatisticsHeader /project/
done 