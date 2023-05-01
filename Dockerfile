ARG JDK_VERSION=17

# BUILD
FROM ghcr.io/fantom-lang/fantom:master AS build

WORKDIR /opt

# Clone and build haystack-defs
RUN git clone https://github.com/Project-Haystack/haystack-defs.git && \
  cd haystack-defs && \
  touch fan.props && \
  fan src/build.fan

# Copy and build haxall
COPY . haxall
WORKDIR /opt/haxall
RUN echo "path=/opt/haystack-defs/;" > fan.props && \
  fan src/build.fan


# RUN
FROM eclipse-temurin:$JDK_VERSION as run

WORKDIR /opt/haxall

# Combine built binaries, pods, and config
COPY --from=build /opt/fan/bin/ bin/
COPY --from=build /opt/fan/etc/ etc/
COPY --from=build /opt/fan/lib/fan/ lib/fan/
COPY --from=build /opt/fan/lib/java/sys.jar lib/java/sys.jar
COPY --from=build /opt/haystack-defs/etc/ etc/
COPY --from=build /opt/haystack-defs/lib/ lib/
COPY --from=build /opt/haxall/bin/ bin/
COPY --from=build /opt/haxall/etc/ etc/
COPY --from=build /opt/haxall/lib/ lib/
COPY ./docker/hx_start bin/

# Set up binary environment and check that we can run hx
ENV PATH $PATH:/opt/haxall/bin
RUN chmod +x bin/* && \
  hx version

# Specify project mount volume
VOLUME /opt/haxall/proj/

# Start haxall
ENTRYPOINT hx_start