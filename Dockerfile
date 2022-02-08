FROM membraneframeworklabs/docker_membrane
WORKDIR /project
COPY ./ /project
RUN mix deps.get
RUN mix compile
CMD ["mix", "run", "./lib/PushMode/run.exs"]