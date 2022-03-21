FROM membraneframeworklabs/docker_membrane
USER root
RUN asdf install elixir ref:master
RUN asdf global elixir ref:master
WORKDIR /project
COPY ./lib /project/lib
COPY ./test /project/test
COPY ./mix.exs /project/mix.exs
COPY ./config /project/config
RUN mix local.rebar --force && mix local.hex --force && mix deps.get
RUN mix compile
COPY ./boot_script.sh /project/boot_script.sh
#CMD ["bash", "./boot_script.sh"]
CMD ["mix", "test"]