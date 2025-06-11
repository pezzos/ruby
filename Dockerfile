FROM ruby:3.1

# Install and configure locales
RUN apt-get update && apt-get install -y locales \
    && sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
    && dpkg-reconfigure --frontend=noninteractive locales \
    && update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/* # Clean up apt lists
ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

ARG USER
RUN useradd -m -s /bin/bash $USER

# Support for MacOS path compatibility (Keep for now, test removal later if desired)
RUN ln -s /home /Users

# Install common development tools and dependencies using BuildKit cache mount
RUN --mount=type=cache,target=/var/cache/apt \
    apt-get update && apt-get -y install \
    vim \
    graphviz \
    git \
    build-essential \
    libxml2-dev \
    libxslt-dev \
    pkg-config \
    libyaml-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/* # Clean up apt lists again after install

# Set build environment for ARM64 (Keep for now)
ENV NOKOGIRI_USE_SYSTEM_LIBRARIES=1
ENV CFLAGS="-Wno-error"
ENV ARCHFLAGS="-arch arm64"
ENV RUBY_CONFIGURE_OPTS="--with-arch=arm64"

# Configure Ruby and Bundler
ENV RUBY_VERSION=3.1.0
ENV GEM_HOME=/usr/local/bundle
ENV BUNDLE_PATH=/usr/local/bundle
ENV PATH=$GEM_HOME/bin:$PATH

# Update RubyGems and install required gems with specific versions using BuildKit cache mount
# Consider moving non-essential gems like chef-cli to Gemfile
RUN --mount=type=cache,target=$GEM_HOME/cache \
    gem update --system && \
    gem install psych -v 5.2.3 --no-document && \
    gem install bundler -v 2.5.23 --no-document && \
    gem install rubygems-update && \
    gem install chef-cli -v 5.6.1 --no-document

# Create directories for locks and bundle cache
RUN mkdir -p /usr/local/bundle /var/lock/ruby-dev && \
    chown -R $USER:$USER /usr/local/bundle /var/lock/ruby-dev

# Set up the working directory
WORKDIR /workspace

# Add local user binaries to PATH
ENV PATH="/home/$USER/.local/bin:${PATH}"

# Copy and set up entrypoint script before changing user
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Switch to non-root user after all root operations are complete
USER $USER

# Define volumes
VOLUME ["/usr/local/bundle", "/var/lock/ruby-dev"]

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bash"]
