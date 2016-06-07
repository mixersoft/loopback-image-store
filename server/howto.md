Loopback: image-store
// see https://github.com/strongloop/loopback-component-storage/tree/master/example-2.0/server

# Install
```
sudo npm install -g strongloop
slc loopback
# folder: loopback-image-store

cd loopback-image-store
	# edit ./server/boot/config.json
	# set host='loopback'

npm install loopback-component-storage
slc loopback:datasource
# choose connector=other
# edit ./server/datasources.json, see: http://docs.strongloop.com/display/public/LB/Storage+service

// see https://github.com/strongloop/loopback-component-storage/tree/master/example-2.0/server
// copy ./examples-2.0/models
mkdir ./server/storage
# update model-config.json with container model
```

## config for localhost testing
- config.json: change host='localhost'
- datasources.json: change storage.root == 'svc/storage'



# Run
```
ssh [server]
cd /path/to/loopback-image-store/

# production, run detached
./slc-run
slc runctl status # restart | stop

# dev
slc run
```

# TODO:
- add cleanup method to delete orphaned files
- add authentication?? prevent adding photos to user accounts via spoofing?
- add CORS
X-Container-Identifier- serve from /www-svc/svc with auto-render
- chgrp of container www-data, create .thumbs subfolder for autorender.php

parse src:
http://files.parsetfss.com/71cef948-2ad9-4e4a-9d90-499bad3149c0/tfss-b51da11f-0028-4e84-bdd5-a00310c43d7b-E8314E72-F57C-40D0-9CA3-170A2AD8B298.jpg




# Test (on client)
- api explorer: http://hostname:8765/explorer/
- demo: http://hostname:8765/client/
- from terminal:

curl -X POST -H "Content-Type: image/jpeg" \
	-H  'X-Image-Identifier: 2A456415-B1AE-424A-9795-A0625A768EBD/L0/001' \
	-H  'X-Container-Identifier: DEQBCEektV' \
	--data-binary '@./svc/storage/DEQBCEektV/IMG_0800.PNG' \
	http://app.snaphappi.com:8765/api/containers/DEQBCEektV/upload


# download container example:
 http://localhost:8765/api/containers/container1/downloadContainer/IMG_0799.PNG,IMG_0800.PNG  
 http://localhost:8765/api/containers/container1/downloadContainer/all


curl -X POST -H "Content-Type: image/jpeg" \
  -H  'X-Image-Identifier: image-800' \
  -H  'X-Container-Identifier: DEQBCEektV' \
  --data-binary '@./IMG_0800.PNG' \
  http://app.snaphappi.com:8765/api/containers/test/upload

curl -X POST -H "Content-Type: image/jpeg" \
  -H  'X-Image-Identifier: image-800' \
  -H  'X-Container-Identifier: test' \
  -H  'X-Full-Res-Image: true' \
  --data-binary '@./IMG_0800.PNG' \
  http://app.snaphappi.com:8765/api/containers/test/upload  


curl -X POST -H "Content-Type: image/jpeg" \
  -H  'X-Image-Identifier: 314ddd3a-081d-405a-a831-cc44ae62c26f' \
  -H  'X-App-Identifier: macata' \
  -H  'X-Container-Identifier: fNnreAFrrcsiX4syj' \
  -H  'X-Full-Res-Image: true' \
  --data-binary '@./svc/storage/container1/IMG_0800.PNG' \
  http://app.snaphappi.com:8765/api/containers/fNnreAFrrcsiX4sy/upload  



