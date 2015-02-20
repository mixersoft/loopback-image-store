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