Loopback: image-store
// see https://github.com/strongloop/loopback-component-storage/tree/master/example-2.0/server

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
update model-config.json with container model

TODO:
- add cleanup method to delete orphaned files
- add authentication?? prevent adding photos to user accounts via spoofing?
- add CORS
- serve from /www-svc/svc with auto-render
- chgrp of container www-data, create .thumbs subfolder for autorender.php

parse src:
http://files.parsetfss.com/71cef948-2ad9-4e4a-9d90-499bad3149c0/tfss-b51da11f-0028-4e84-bdd5-a00310c43d7b-E8314E72-F57C-40D0-9CA3-170A2AD8B298.jpg



