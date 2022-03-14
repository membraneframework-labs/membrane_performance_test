# Membrane Performance Test
Membrane Performance Test checks the performance of the Membrane Core, by finding a maximal possible throughput of the linear pipeline, which doesn't lead to the messages congestion. 

## Usage
Test can be launched with the mix task command:
`mix performance_test`
`--mode <push|pull|autodemand>`
`--numberOfElements <number of elements>`
`--howManyTries <how many tries>`
`OPTIONAL:`
`--tick <single try length [ms], default: 10_000>`
`--initialGeneratorFrequency <frequency of the message generator in the first run, default: 50_000 msg/s>`
`--chosenMetrics <comma separated list of statistic names which should be saved, default: '', available_metrics: throughput|generator_frequency|passing_time_avg|passing_time_std>`
`--reductions <number of reductions to be performed in each filter, while processing buffer, default: 10_000>`
`SWITCHES:`
`--shouldAdjustGeneratorFrequency, --shouldProducePlots, --shouldProvidemetricsHeader`
`ARG:`
`<output directory path>`

As a result, a csv file called `stats.csv` will be produced in the *output directory path*, containing the desired metrics. If `--shouldProvideStatisticsHeader` flag is defined, the chosen statistics names header will be present on the top of the result file.  If `--shouldProducePlots` optional flag is defined, in that directory there will also appear a `plot/` directory, with `*_plot.svg` files inside, which are **MessagePassingTime(TimeWhenTheMessageWasSent)** plots.
Available metrics: `throughput, generator_frequency, passing_time_avg, passing_time_std, tick, tries_counter`

If `--shouldAdjustGeneratorFrequency` flag is set, the binary search of the optimal message generation frequency will be performed.

Some exemplary tests, defined inside the `boot_script.sh` file, can be launched within the docker environment, by:
1) `mkdir results` inside the root project directory
2) Building the image: `docker build -t performance_test .` inside the root project directory
3) Running the container: ``docker run -v `pwd`/results:/project/results/ performance_test`` inside the root project directory

## Copyright and License

Copyright 2020, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane_template_plugin)

[![Software Mansion](https://logo.swmansion.com/logo?color=white&variant=desktop&width=200&tag=membrane-github)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane_template_plugin)

Licensed under the [Apache License, Version 2.0](LICENSE)
