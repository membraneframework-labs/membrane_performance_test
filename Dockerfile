FROM membraneframeworklabs/docker_membrane
USER root
RUN asdf install elixir ref:master
RUN asdf global elixir ref:master
WORKDIR /project
COPY ./ /project
RUN mix local.rebar --force && mix local.hex --force && mix deps.get
RUN mix compile
RUN elixir -v
#CMD ["bash", "./boot_script.sh"]
CMD ["mix", "test"]