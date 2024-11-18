# Use a minimal base image
FROM python:3.12-alpine

# Install git and python 3.12.3
RUN apk add --no-cache \
    git \
    py3-pip

# Set python3 as the default python
RUN ln -sf python3 /usr/bin/python

# Verify installation
RUN python --version && git --version


# Clone the repository
RUN git clone https://github.com/kyle-pena-nlp/mflux.git /app/mflux

# Set the working directory
WORKDIR /app/mflux

# Create and activate the .venv (some packages won't let you install without being in a venv, annoyingly)
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

RUN pip install mlx

# Install the repository contents using pip
RUN pip install .

# Install/download the model (this is where layer caching will help)
RUN python /app/mflux/src/install_hf_model.py --model_alias schnell

# Expose port 3000 for the waitress server
EXPOSE 3000

# Start the waitress server on port 3000
CMD ["python", "/app/mflux/src/server.py", "--port", "3000"]