git pull && \
docker build -t isuwang-blog -f ./docker/Dockerfile . && \
docker stop isuwang-blog && \
docker rm isuwang-blog && \
docker run -p 4000:4000 --name isuwang-blog -d  isuwang-blog