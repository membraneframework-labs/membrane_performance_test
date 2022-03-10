FROM membraneframeworklabs/docker_membrane
USER root
WORKDIR /project
COPY ./ /project
RUN mix deps.get
RUN mix compile
CMD ["bash", "./boot_script.sh"]
#CMD ["mix", "test"]