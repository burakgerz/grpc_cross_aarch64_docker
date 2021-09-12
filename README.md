# grpc_cross_aarch64_docker

1. Get latest Docker

2. Get Docker Buildx
https://docs.docker.com/buildx/working-with-buildx/

3. Clone this repo, change into it and build the image with command "docker buildx build . -t grpc-x86-cc-aarch64"

4. Run the image with "docker run -dit grpc-x86-cc-aarch64"

5. Get files from running docker container e.g. with docker cp <containerID>:/build_arm ./
