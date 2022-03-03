FROM membraneframeworklabs/docker_membrane
USER root
WORKDIR /project
COPY ./ /project
RUN mix deps.get
RUN mix compile
#RUN chmod +x boot_script.sh
#CMD ["ls", "-la"]
CMD ["bash", "./boot_script.sh"]
#CMD ["mix", "performance_test", "--mode", "pull", "--n", "30", "--howManyTries", "1", "--tick", "10000", "--initialLowerBound", "10000", "--initialUpperBound", "10000", "/project/"]
#CMD ["mix", "test"]