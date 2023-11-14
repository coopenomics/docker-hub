```
docker build -t cdt_v4.0.0 .
docker tag cdt_v4.0.0 dicoop/cdt_v4.0.0
docker push dicoop/cdt_v4.0.0
docker run --rm --name cdt_v4.0.0 --volume /path-to-your-project:/project -w /project dacomfoundation/cdt_v4.0.4 /bin/bash -c "eosio-cpp -abigen -I include -R include -contract reg -o reg.wasm registrator.cpp"
```

```
docker build -t leap_v4.0.4 .
docker tag leap_v4.0.4 dicoop/leap_v4.0.4
docker push dicoop/leap_v4.0.4
```
