# To use this Docker image, make sure you set up the mounts properly.
#
# The Minecraft server files are expected at
#     /home/minecraft/server
#
# The Minecraft-Overviewer render will be output at
#     /home/minecraft/render

FROM debian:buster as builder

RUN apt-get update && \
    apt-get install -y git python3.7-dev python3-pil python3-numpy python3-pip python3-distutils python3-wheel

ADD ./external/overviewer /usr/src/overviewer/

WORKDIR /usr/src/overviewer

# There's an issue with Minecraft-Overviewer where it uses distutils which
# doesn't allow for usage of bdist_wheel, so we patch it out as a hack.
RUN sed -i 's/from distutils.core import setup/from setuptools import setup/' ./setup.py

# Build a wheel so we can copy it into the actual container without requiring
# some of the build deps.
RUN python3 setup.py bdist_wheel

RUN ls ./dist

# Switch to the python image so we get a smaller overall image
FROM python:3.7-slim-buster

LABEL MAINTAINER = 'Mark Ide Jr (https://www.mide.io)'

# Default to do both render Map + POI
ENV RENDER_MAP true
ENV RENDER_POI true

# Only render signs including this string, leave blank to render all signs
ENV RENDER_SIGNS_FILTER "-- RENDER --"

# Hide the filter string from the render
ENV RENDER_SIGNS_HIDE_FILTER "false"

# What to join the lines of the sign with when rendering POI
ENV RENDER_SIGNS_JOINER "<br />"

ENV CONFIG_LOCATION /home/minecraft/config.py

COPY --from=builder /usr/src/overviewer/dist/Minecraft_Overviewer-unknown-cp37-cp37m-linux_x86_64.whl ./
RUN pip install --no-cache Pillow numpy && pip install --no-cache -U Minecraft_Overviewer-unknown-cp37-cp37m-linux_x86_64.whl

RUN groupadd minecraft -g 1000 && \
    useradd -m minecraft -u 1000 -g 1000 && \
    mkdir -p /home/minecraft/render /home/minecraft/server

COPY config/config.py /home/minecraft/config.py
COPY entrypoint.sh /home/minecraft/entrypoint.sh
COPY download_url.py /home/minecraft/download_url.py

RUN chown minecraft:minecraft -R /home/minecraft/

WORKDIR /home/minecraft/

USER minecraft

CMD ["bash", "/home/minecraft/entrypoint.sh"]
