FROM nfcore/base
LABEL description="Docker image containing all requirements for lehtiolab/helaqc pipeline"

COPY environment.yml /

RUN conda env create -f /environment.yml && conda clean -a
ENV PATH /opt/conda/envs/helaqc-2.2/bin:$PATH

# For dinosaur
RUN apt update && apt install -y fontconfig && apt clean -y
