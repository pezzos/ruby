FROM ruby:3.1

ARG USER
RUN useradd -m -s /bin/bash $USER

# Support for MacOS path compatibility
RUN ln -s /home /Users

# Install common development tools
RUN apt update && apt -y install \
    vim \
    graphviz \
    git \
    build-essential \
    && apt clean

# Set up the working directory
WORKDIR /workspace

# Add local user binaries to PATH
ENV PATH="/home/$USER/.local/bin:${PATH}"

# Copy and set up entrypoint script before changing user
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Switch to non-root user after all root operations are complete
USER $USER

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bash"]
