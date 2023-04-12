FROM debian:10-slim

RUN apt-get update -qq && \
	apt-get install -qq --no-install-recommends \
	g++ \
	make \
	automake \
	autoconf \
	bzip2 \
	unzip \
	wget \
	sox \
	libtool \
	git \
	subversion \
	python2.7 \
	python3 \
	zlib1g-dev \
	ca-certificates \
	gfortran \
	patch \
	ffmpeg \
	vim && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

ENV DIR_GENTLE=/gentle
ENV DIR_KALDI=${DIR_GENTLE}/ext/kaldi
ENV DIR_KALDI_TOOLS=${DIR_KALDI}/tools
ENV DIR_KALDI_SRC=${DIR_KALDI}/src

WORKDIR ${DIR_GENTLE}

COPY . .

RUN git submodule update --init --recursive

# 01. Creates a symbolic link to python3 as python (required by Kaldi)
# 02. Installs the mandatory Kaldi tools 
# 03. Installs the OpenBLAS library (required by Gentle) Note: The script
#     install_openblas.sh will prompt the user, so we use the yes command to
#     answer yes to all the prompts
# 04. Configures Kaldi
# 05. Installs the Gentle models
# 06. Compiles Gentle (Kaldi and Gentle are compiled in a single step)
# 07. Removes the Kaldi and Gentle built files and artifacts
# 08. Removes the Kaldi and Gentle git directories Note: All the steps are done
#     in a single RUN command to avoid creating intermediate layers, which would
#     increase the image size
RUN cd ${DIR_GENTLE} && \
	python3 setup.py develop \
	ln -s /usr/bin/python3 /usr/bin/python && \
	cd ${DIR_KALDI_TOOLS} && \
	make -j $(nproc) -w -s && \
	MAKEFLAGS="-j $(nproc) -w -s" \
	./extras/install_openblas.sh && \
	cd ${DIR_KALDI_SRC} && \
	./configure --static --static-math=yes --static-fst=yes --use-cuda=no --openblas-root=${DIR_KALDI_TOOLS}/OpenBLAS/install && \
	cd ${DIR_GENTLE} && \
	yes | ./install_models.sh && \
	cd ${DIR_GENTLE}/ext && \
	make -j depend && \
	make -j $(nproc) -w -s && \
	find ${DIR_KALDI} -type f \( -name "*.o" -o -name "*.la" -o -name "*.a" \) -exec rm {} \; && \
	find ${DIR_GENTLE}/ext -type f \( -name "*.o" -o -name "*.la" -o -name "*.a" \) -exec rm {} \; && \
	rm -rf ${DIR_GENTLE}/.git && \
	rm -rf ${DIR_KALDI}/.git

EXPOSE 8765

VOLUME /gentle/webdata

CMD cd /gentle && python3 serve.py